# 启动性能基线（Performance Baseline）

启动计时埋点（LB-16）+ 预算验收线。埋点由 `LifecycleTimer`
（`lib/services/lifecycle_timer.dart`）产出，`main.dart` 在各 bootstrap 阶段调用。

## 埋点

每个阶段结束落一条结构化日志：

```json
{"level":"INFO","module":"app.lifecycle","msg":"stage complete","extra":{"stage":"<name>","ms":<elapsed>}}
```

- 模块名 `app.lifecycle`、`stage` 值、`msg` 均为英文常量（非用户可见文案）。
- 计时走注入的**单调** `ElapsedSource`（生产 `StopwatchElapsed` 基于 `Stopwatch`
  单调时钟；单测 `FakeElapsed` 手动推进）。选单调源的真实理由有二：其一可注入/
  可伪造，故 `ms` 在测试里确定性可断言；其二免受启动期墙钟跳变（NTP 校正 / 手动
  改表）污染——冷启 `pg_ready`（含 `initdb`，紧随开机、首次 NTP 校正易落此窗口）
  是唯一的冷启基线样本，墙钟阶跃会把它写成负数或虚高。

### 阶段清单

| stage | 覆盖范围 | 起点 |
|---|---|---|
| `paths` | `DefaultAppPaths.create` + `ensureInitialized`（首启建目录树） | 阶段进入 |
| `package_info` | `PackageInfo.fromPlatform`（读版本号） | 阶段进入 |
| `media_kit` | `MediaKit.ensureInitialized` | 阶段进入 |
| `window_manager` | `windowManager.ensureInitialized` | 阶段进入 |
| `preload` | 偏好 + `custom_providers.json` 磁盘预加载 | 阶段进入 |
| `run_app` | `runApp` 同步调度（首帧尚未渲染） | 阶段进入 |
| `first_frame` | 首帧渲染完成（post-frame 回调） | **进程起点**（main 入口） |
| `pg_ready` | 内嵌 PG 启动 + 建池 + 迁移链（`pgMigratedPoolProvider` 结算） | **进程起点** |

`first_frame` / `pg_ready` 从进程起点起算，对应“启动到可见 / 启动到库可用”的
端到端时长；其余阶段为该阶段自身耗时。

> 读数注意：PG 在 `runApp` 后被主动读一次以触发迁移池构建（原本懒启），这把 PG
> 引导与首帧光栅化并行了。故 `first_frame` 反映的是**与 PG bootstrap 并发**下的
> 首帧耗时（PG 启动抢占 CPU/IO 可能略微抬高首帧），而非纯 UI 渲染时长——对比历史
> 数据时按此口径读。

### 采集方法

日志落 `<数据根>/logs/inkframe.log`（单行 JSON；数据根=Win `%LOCALAPPDATA%\InkFrame`、
macOS `~/Library/Application Support/InkFrame`，DIR-1）。抽取（macOS 例）：

```bash
grep '"module":"app.lifecycle"' ~/Library/Application\ Support/InkFrame/logs/inkframe.log
```

## 预算验收线（阈值）

冷启 = 首次启动，需 `initdb` 建库；温启 = 库已存在的后续启动。

| 场景 | 指标（stage） | 阈值 |
|---|---|---|
| 温启 | `first_frame` | < 2s |
| 温启 | `pg_ready` | < 5s |
| 冷启（含 initdb） | `pg_ready` | < 15s |

## 实测记录（双平台）

> 阈值以上为验收上限；下表为真机实测值。**当前为占位**——本卡在无真机的
> 环境实现，不得编造实测数字（编造会污染性能回归基线）。请在真实 macOS /
> Windows 上按上述采集方法各跑冷启 + 温启一次，回填中位数（建议 ≥3 次取中位）。

| 场景 | 指标 | 阈值 | macOS 实测 | Windows 实测 |
|---|---|---|---|---|
| 温启 | `first_frame` | < 2s | TODO(measure on real macOS/Windows) | TODO(measure on real macOS/Windows) |
| 温启 | `pg_ready` | < 5s | TODO(measure on real macOS/Windows) | TODO(measure on real macOS/Windows) |
| 冷启 | `pg_ready`（含 initdb） | < 15s | TODO(measure on real macOS/Windows) | TODO(measure on real macOS/Windows) |

回填时一并记录机器规格（CPU / 内存 / 磁盘类型）与 app 版本，便于跨机比较。
