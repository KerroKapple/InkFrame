# InkFrame 执行手册(EXECUTION-PLAYBOOK)

> **这是什么**:在本仓库做任何开发的**操作规程**——已被 2026-07 密集开发期(M2 收官 + M3 四切片
> + 全量文档对账,14+ PR 全绿合入)验证过的流水线、工具链地雷、架构不变量与质量方法。
> **给谁看**:后续执行者(人或 AI,含能力较弱的模型)。任务卡在 [`MASTERPLAN.md`](MASTERPLAN.md);
> 本文回答「怎么做才不踩坑」。铁律原文见 [`CLAUDE.md`](CLAUDE.md),本文不重复只引用。
> **维护**:发现新地雷/新不变量,随发现它的 PR 同步补进来。

---

## 1. 标准开发循环(每个任务卡都走这条流水线)

```
任务卡(MASTERPLAN)→ 从 main 切分支 → TDD 实现(先红后绿)→ 自查闸门
→ 两路评审(对抗评审 + 独立复跑)→ 修完全部 P1/P2 与低成本项 → 全量闸门
→ conventional commit → push → PR → CI 全绿 → 合并(squash)→ 删分支
```

逐步说明:

1. **切分支**:`git checkout -b <type>/<slug>`(main 上禁止直接提交)。type = feat/fix/refactor/test/docs。
2. **TDD 先红后绿**:先写测试跑红(留存红运行记录),再实现转绿。新逻辑没有测试 = 评审必打回。
3. **自查闸门**(实现完成的定义,四条全过):
   - `flutter analyze` 0 issue(flutter 路径见 §2.1)
   - `flutter test` 全量:允许且**仅允许** `node_card_golden_test.dart` 的 3 个已知 Windows
     像素假阳性(见 §2.3);失败数 >3 或出现其他用例名 = 你改坏了
   - ARB en/zh key 集完全一致(`test/l10n/arb_hygiene_test.dart` 闸门)
   - `git status` 无意外文件(pubspec/freezed 生成物不该动时没动)
4. **两路评审**(不可省,历史上每个"自查全绿"的切片仍被评审揪出 1-6 个缺陷):
   - **对抗评审**:另起一个读代码的评审者,前提是"默认有 bug,构造反例"。给它:改动概要、
     语义基准(拍板决策)、重点怀疑区(见 §5 常见缺陷模式)。要求输出
     `findings {severity: P0/P1/P2, file:line, 问题, 反例场景} + verdict: commit-ready|needs-fix`。
   - **独立复跑**:另一个执行者重跑 analyze/全量测试/ARB 比对/新测试单独跑(验顺序依赖),
     核对实现者自报的每个数字。**实现者的自报不作数,以复跑为准**。
5. **修**:P1 全修;P2 修改动成本低的(历史惯例:基本全修);其余记入 BOARD 债表。修完回到第 3 步。
6. **提交**:conventional commit,消息含"做了什么/语义要点/评审修复摘要/测试计数"。
   結尾 `Co-Authored-By` 按仓库惯例。**每个 commit 必须满足第 3 步四条**。
7. **PR + CI**:推送后开 PR;CI 五件套(analyze+lint / test+coverage 70% 闸 / golden /
   release scripts / secret-scan)全绿才可合并;squash 合并后删分支(本地+远端)。

**检查点例外**:长任务中途怕丢工作,允许打 WIP checkpoint commit(消息注明"勿作测试绿基线"),
完成后 `git reset --soft` 合成一个干净 commit 再推——仅限**未推送**的本地链。

## 2. 工具链地雷(症状 → 原因 → 规避)

### 2.1 flutter 不在 PATH(仅 Windows 机)
- **Windows 机**:一律用绝对路径 `C:\Users\Kerro\flutter\bin\flutter.bat` / `dart.bat`
  (POSIX shell 下 `C:/Users/Kerro/flutter/bin/flutter.bat`)。
- **macOS 机**:flutter 在 PATH,直接 `flutter` / `dart`。

### 2.2 build_runner 全量构建损坏(高危)
- **症状**:`dart run build_runner build` 在 riverpod_generator 处理 `lib/app.dart` 时崩
  `Missing implementation of visitDotShorthandInvocation` 且**挂死**;崩溃还可能**误删**未改动的
  `.freezed.dart`(事后 `git checkout` 恢复,提交前必查 `git status`)。
- **原因**:锁定的 analyzer 7.4.5 无法序列化 Dart 3.11 SDK 的 dot-shorthand 语法节点
  (详见 `docs/BLOCKERS-2026-07-06.md` §2)。
- **规避**:**永远不跑全量**。改了 freezed 模型时定向生成:
  `dart.bat run build_runner build --delete-conflicting-outputs --build-filter=lib/path/to/x.freezed.dart`
  (可多个 `--build-filter`,含 `.g.dart`)。根修等 freezed 3.2.6(盯 freezed#1353)。

### 2.3 golden 测试的 3 个 Windows 假阳性
- `node_card_golden_test.dart` 的 idle/selected/link_source 三例在 Windows 本机恒失败
  (像素 diff ≈1%,字体光栅化差异)。**基线锁 CI ubuntu**;本地失败在白名单内可放行,
  但必须逐一核对失败用例名恰为这三个。重铸基线走 `update-goldens.yml` workflow_dispatch,
  **禁止**本地 `--update-goldens` 产物入库。

### 2.4 测试 tag 与环境开关
- `dart_test.yaml` 注册三 tag:`pg` / `golden` / `ffmpeg`。集成测默认**包含在运行中**、
  由用例内 env 门控自跳(`markTestSkipped`):`TEST_PG_URL` 未设 → pg 集成测 skip;
  `TEST_FFMPEG != '1'` → ffmpeg 集成测 skip。真跑:`TEST_FFMPEG=1 flutter test --tags ffmpeg`。
- 本机全量的 skip 数基线 ≈46;新增门控集成测会 +1,复跑时核对来源。

### 2.5 testWidgets 内禁 await 真实 dart:io
- 会挂死(历史 TD-003)。测试体内文件操作用 `*Sync` API。

### 2.6 coverage 口径
- 裸 lcov 数字误导。用 `scripts/coverage/report.sh`(镜像 CI 口径);exclude 清单的
  **单一事实源是 `ci.yml`**。CI 闸门 70%。

### 2.7 其他
- git 输出大量 `LF will be replaced by CRLF` 警告:无害噪音,忽略。
- hooks 状态分机器:**Windows 机**未设 `core.hooksPath`(flutter 不在 PATH 所致),hook 逻辑由
  CI 兜底、自查闸门(§1.3)手动跑;**macOS 机** `.git/hooks/pre-commit|pre-push` 已符号链接到
  `scripts/hooks/`(pre-push=analyze+全量测试排 golden),本地闸门真实生效。
- Edit 类工具做精确匹配时注意**全半角标点**(，vs ,):中文文档里极易 old_string 不匹配,
  以 Read 到的原文为准复制。
- ~~系统 python~~ 禁用;脚本比对用 jq / Dart。

## 3. 架构不变量(违者评审必打回;修改它们=先改 ADR)

| # | 不变量 | 出处/后果 |
|---|---|---|
| 1 | `providerRegistryProvider` **只能变异、不能 invalidate** | invalidate 会连锁重建 JobQueue 并触发 init() 孤儿回收,把运行中任务打成 cancelled(`lib/core/di/job_queue.dart`) |
| 2 | `providerCapabilitiesListProvider` 必须**同步可读** | image inspector 在 initState 里 `ref.read` 它;custom 为空时须保持与 const 列表 `identical` |
| 3 | 能力位编译期固定:内置 = const 实例;自定义 = const 协议模板 `copyWith` 派生 | ADR-0009(2026-07-02 修订);禁止能力位来自 .env/DB/网络/用户自由填 |
| 4 | 文件路径**双根**:canvas 根(节点产物,`resolve(projectId, canvasId, rel)`)/ project 根(导出与跨画布读,`resolveInProject(projectId, rel)`,形如 `canvases/<c>/videos/<f>`、`exports/<name>.mp4`) | 换算 = 加 `canvases/<canvasId>/` 前缀;搞混会读错文件(ARCHITECTURE §6) |
| 5 | batch_results slot **只从 'generating' 单向收敛**;部分成功语义:≥1 slot 成功 → job success(首成功图作主图),取消保留已成功 slot,job 对外仍 cancelled | 2026-07-02 拍板;ADR-0008 修订记录;`finalizePending*` 的 WHERE 守卫 |
| 6 | HI-02 取消竞态裁决以 jobs 行为准,**绝不因部分成功补发 success** | `_lostToCancel`/`_arbitrate`(job_queue_service.dart) |
| 7 | key 命名空间统一 `SecureStorageKeys.providerApiKey(<providerId>)`(custom = `provider.custom:<id>.api_key`) | 生成链路校验/inspector 门控/Studio banner 零改动生效的前提 |
| 8 | 禁 `catch Exception/dynamic`;只捕具体 InkError 子类;`PathSecurityError`(ArgumentError 系)在**服务边界**翻译为 `LocalIOError(reason='unsafe_path')`,仅渲染路径 widget 允许直捕它做占位兜底 | ARCHITECTURE §4 |
| 9 | `JobStatus`(Provider 单次 poll 瞬时值)≠ `JobState`(UI 状态机) | ADR-0008;混用必错 |
| 10 | 同步 Provider 一律 `extends SyncProviderBase`(inlineBytes poll 通道,`response_format:'b64_json'`,禁在 provider 内下载 URL) | ADR-0004;JobQueue 对非 Pollable 防御性失败 |
| 11 | 零向后兼容:禁旧格式并行解析/僵尸 API/降级;**但用户数据必须存活**——schema 变更只走追加的前向迁移,不删库、不改已发布迁移 | **已拍板** ADR-0012(D-4);升级唯一路径=前向迁移链,`SchemaDowngradeError` 拒降级 |
| 12 | l10n:用户可见文案必进 ARB 且 en/zh 同 commit;LLM prompt/log/错误码**永不** i18n | CLAUDE.md i18n 节 |

## 4. 评审驱动质量:为什么必须两路

本期数据:6 个"实现者自查全绿"的切片,评审仍揪出 **3×P1 + 20+×P2**(全部有可构造反例)。
实现者的盲区是系统性的,不是能力问题——**永远不要跳过评审直接合并**。

- 对抗评审的必给输入:①改动概要;②**语义基准**(相关拍板/不变量,否则评审者不知道什么算"对");
  ③重点怀疑区。评审重点参考 §5。
- 独立复跑的必查项:analyze / 全量计数逐位核对 / 失败用例名单与白名单比对 / ARB 齐平 /
  新测试文件单独一次调用(顺序依赖)/ `git status` 无意外文件。
- verdict=commit-ready 也要修低成本 findings(本仓惯例);needs-fix 修完必须回到自查闸门重跑。

## 5. 高频缺陷模式(评审史提炼,写代码时自查)

1. **await 间隙后用 ref/context 无 mounted 守卫**(StateError + 副作用静默丢失)——notifier/文案
   在 await **前**预取;成对副作用(节点+边)要保证原子完成或明确降级文案。
2. **async 按钮无 in-flight 防重**(双击双建)——busy 标志 + 方法体内早退双保险;测试用
   gated Completer 制造真并发窗口(InMemory fake 微任务内完成,连点测不出竞态)。
3. **UI 预校验与服务端校验规则漂移**——两边共用一个 util 或逐条对照测试钉死。
4. **fake 与真实实现语义漂移**——fake 的派生列/WHERE 语义必须有 `_harness` 内契约测试 +
   PG 集成测双侧锁定(排序方向这类要**两边都断言**)。
5. **零/空退化边界**(空列表、0 输出、空串 vs null)——"URL 数 < N"的防线在 0 处失守是真实案例。
6. **收敛/清理链新增抛出面**(handle 永挂)——终态收敛必须包成绝不抛出的方法,启动期兜底。
7. **错误语境误推断**(rows==0 ≠ cancel 赢)——用显式语境参数,不从副作用反推。
8. **文档写于代码落地前夜**——README/ADR 提交前 grep 一遍宣称的符号是否存在(幽灵条目)。

## 6. 产品拍板惯例

遇到产品分叉:**列选项(各附一句利弊)+ 给推荐 + 等用户拍板,不擅自定**。拍板结果:
①记入 `docs/BOARD.md` 对应行;②相关骨架/契约文档同步;③实现时作为评审的语义基准引用。
先例:2026-07-02 四项(json 存储/协议白名单/部分成功/取消保留)。

## 7. 文档体系地图(改代码时同步哪份文档)

| 文档 | 角色 | 何时动 |
|---|---|---|
| `docs/BOARD.md` | **单一事实源**:状态/债表/拍板 | 每个 PR 若改变状态即同步 |
| `docs/MASTERPLAN.md` | 任务库:epic→任务卡(本手册的伴生文档) | 任务完成打勾/新任务入库 |
| `docs/CLAUDE.md` | 铁律 + 结构快照 | 增删目录/文件同 commit 更新快照 |
| `docs/ARCHITECTURE.md` / `PROVIDER-API.md` / `DATABASE.md` | 契约(签名级) | 改契约的 PR 内同步 |
| `docs/adr/` | 决策记录;修订走"修订记录"段(见 0008/0009 先例),索引加 rev 注记 | 架构级决策变化时 |
| `lib/features/*/README.md` | 模块速查(文件清单/数据流) | 模块内增删文件同 commit |
| 4 份 launch 明细 plan(`docs/superpowers/plans/2026-07-07-launch-*.md`) | 冻结开工快照(2026-07-07) | 永不回写完成状态;开卡前按当前 main 复核 file:line |
| `docs/TESTING.md` / `SETUP.md` / `BUILD-RELEASE.md` | 操作手册 | 相应流程变化时 |
| 归档快照(带 banner) | 只读历史 | 永不更新 |

> 2026-07-07 全量对账(PR #142)后以上全部与代码对齐;让它保持对齐的成本远低于再来一次对账。
