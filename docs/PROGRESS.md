# Progress — 当前进度快照（docs 设计 × 代码实测）

> 快照日期：2026-06-26 · HEAD `a5ba6a0`（后端 P0–P2 加固 #127–#132 已落）
> 核对基准：`lib/` **181** 个 Dart 文件、`test/` **169** 个。
> 本文逐项把设计文档要交付的能力，对照【当前代码】核实状态——非照抄文档勾选。
>
> 与其它文档的关系：
> - `ROADMAP.md` 列「方向与认领」；
> - `ROAD-TO-BETA.md` 列「到 beta 的收口路径与 DoD」（其快照为 2026-06-11，已落后于代码）；
> - **本文**列「截至上方日期，每条能力的实测落地状态」。
>
> 图例：✅ 已完成 · 🟡 部分/缺收口 · ⬜ 已设计未建 · ⬛ 未开始 · 🚫 明确不做 · ❓ 代码侧无法判定

---

## 0. 一句话现状

骨架成熟、核心创作闭环可跑（建节点 → 生成 → JobQueue 状态机 → 落盘 → 渲染），后端刚做完 P0–P2 加固。离 beta 的门槛不是功能广度，而是质量基建的「实跑绿」确认 + 几处 P1 收口。

| 维度 | 状态 |
|---|---|
| 阶段 | alpha 收口期（积压未打 tag → alpha.10） |
| 核心闭环 | ✅ 可运行（fire-and-forget + JobsRegistry + CanvasRenderQueue 真数据） |
| Provider | ✅ 9 款 code-complete（Gemini / OpenAI / Stability 同步 + Wanx×4 / Kling×2 异步） |
| 存储 | ✅ 嵌入式 PG + 迁移 v5 + UnitOfWork 事务；🟡 P1 加固未完 |
| i18n | ✅ en/zh key 集合 213↔213 完全对齐 + 守卫测试 |
| 设计 Token | ✅ Amber Noir 三套主题落地，`lib/features` 硬编码样式 ≈ 0 |
| Beta DoD | ~6/8 达成，1 项待 CI 实跑确认，1 项待查 issue |

---

## 1. Beta Definition of Done 记分卡（最关键）

对应 `ROAD-TO-BETA.md` §3 的八条。`*` = 闸门在 CI 中强制存在，但未在本快照中实跑确认。

| # | DoD 条目 | 状态 | 证据 / 说明 |
|---|---|---|---|
| 1 | `flutter analyze` 干净 | ✅* | `ci.yml` 硬闸 + `analysis_options.yaml`（strict-casts/inference） |
| 2 | `flutter test` 全绿 | ✅* | `ci.yml` 全量跑 + coverage；无 FLAKY 登记 |
| 3 | Golden 基线存在 + CI 校验 | ✅ | `test/features/canvas/widgets/goldens/` 3 张 PNG（node_card idle/selected/link_source）；`ci.yml` golden job「有基线却 ran=0 → exit 1」；`update-goldens.yml` 在 ubuntu 重生成 |
| 4 | ≥1 条 E2E 主链路 | ✅ | `test/e2e/generation_pipeline_e2e_test.dart`（提交→终态→落盘）+ `generation_render_node_e2e_test.dart`（落盘产物经真实 FileResolver 渲染） |
| 5 | Win+mac 双烟测通过 | 🟡 | `smoke.yml`（macos-14 + windows-latest）+ `scripts/smoke/{macos-smoke.sh,windows-smoke.ps1}` 已就位；**首次 CI 实跑绿未确认** |
| 6 | 性能基线文档化 | ✅ | `docs/internal/perf-baseline.md`（50–400 节点耗时表）+ `canvas_scale_perf_test.dart`（N=400 build<8s、hitTest N=3000<50ms 护栏） |
| 7 | 覆盖率 ≥70% | ✅* | `ci.yml` 用 `very_good_coverage min_coverage:70`（含 media_kit/生成代码排除）；当前实际 % 见 `scripts/coverage/report.sh` |
| 8 | 无 P0 open bug | ❓ | 代码侧无法判定，需查 GitHub Issues `label:P0` |

**结论：代码侧无 beta 阻塞项。剩两件人工事：① 手动触发 `smoke.yml`/`update-goldens.yml` 确认首跑绿；② 清点 P0 issue。**

---

## 2. 按领域进度清单

### 2.1 Canvas / 节点编辑器
| 能力 | 状态 | 证据 |
|---|---|---|
| 节点 增/删(软删级联)/选中、连线增删、连线选中态 | ✅ | `canvas_nodes_controller.dart` / `canvas_edges_controller.dart` / `selected_edge_controller.dart` + 测试 |
| Inspector autosave、FAB 加节点 | ✅ | `inspector_submit_controller.dart`(debounce) / `canvas_add_node_fab.dart` |
| Style Lanes（模型+几何+背景+标题栏+prompt 拼接+节点归属） | ✅ | `style_lane.dart` / `lane_geometry.dart` / `lane_background.dart` / `prompt_assembler.dart` |
| 生成集成（fire-and-forget + RenderQueue + JobListener） | ✅ | `canvas_render_queue.dart` / `canvas_job_listener.dart` / `canvas_job_effects.dart` |
| 连线 midpoint 删除按钮 | 🟡 | `EdgePainter` 当前 `IgnorePointer`，交互留后续 PR |
| Undo/Redo 全覆盖 | ⬜ | 无 UndoStack/CommandHistory（ROADMAP Help Wanted） |
| 节点 group/collapse | ⬛ | 无任何实现 |
| 缩放性能 >200 节点动态降级 | 🟡 | 有性能测试护栏，但**无运行时降级**（依赖未建的 ARCH §10 控制器） |

### 2.2 生成闭环 / JobQueue
| 能力 | 状态 | 证据 |
|---|---|---|
| 持久化状态机(7态)+双层并发+token bucket 限流+轮询退避 | ✅ | `job_queue_service.dart` / `rate_limiter.dart`（默认 3s→30s ×2.0，超时 30m） |
| O(1) cancel（软删+pendingIndex map，N=10000<50ms） | ✅ | `cancel()` + cancel bench test |
| batch results 落盘(inlineBytes/remoteUrls)、canvasId 维度、写库顺序不变量 | ✅ | `job_state.dart` / `_persistRemoteUrls` / `job_queue_service_writeback_order_test.dart` |
| 自动重试调度 | ⬜ | 仅可重试白名单已定义；当前进 error 终态由 UI 人工重试（ARCH §5.3） |
| 下载断点续传 | ⬜ | `dio_video_download_service` 无 HTTP Range（ARCH §8） |

### 2.3 AI Provider 适配层
| 能力 | 状态 | 证据 |
|---|---|---|
| 9 款 Provider + registry + rate_limiter + dio_error_mapper | ✅ | `lib/core/di/providers.dart` 全注册；`SyncProviderBase` + `DashScopeAsyncProviderBase` 抽公共 |
| fixture-E2E 回放 | 🟡 | Gemini/Wanx/Kling fixtures 齐；**OpenAI/Stability 部分缺**（BLOCKED 待真 key，PROVIDER-API §12.3 禁手写） |
| estimateCost + 成本 UI | ⬜ | grep 无；`CostModel` 模型已定义但无消费端（§4） |
| custom_providers.json 加载 | ⬜ | grep 无；registry 仍 unmodifiable Map（§13） |
| QuotaAware/getQuota | ⬜ | 已删待重立项（commit "drop dead QuotaAware"） |
| Open 列表(SD/MJ/DALL-E/Runway/Pika/Luma/Jimeng/Hailuo/Kling 官方) | ⬜ | 9 款全 🟢 Open，0 实现 |

### 2.4 存储层 / 嵌入式 PostgreSQL
| 能力 | 状态 | 证据 |
|---|---|---|
| PG 生命周期 + binary locator + 迁移 runner(v1→**v5**) + 7 repository | ✅ | `pg_controller.dart` / `migration_runner.dart` / `schema_v5.dart` |
| UnitOfWork 多步写事务(P0#1) + SchemaDowngradeError + 批量回收 | ✅ | `unit_of_work.dart` + 3 调用站点；启动 `bulkTransition` orphan 回收 |
| DbRow 类型化 + 列名常量(P0#2) | 🟡 | ~90–95%；Job/Canvas/Project 部分 row 仍散读 |
| Provider 响应解析防御(P1-4) | 🟡 | `(x as Map)['k']` 仍无 try→`providerInvalidResponse` |
| JobsRegistry 硬上限/淘汰(P1-5d) | 🟡 | 无上限，长会话有泄漏风险 |
| P2（慢查询日志/显式列/downgrade 友好退出） | ⬜ | 低优先，未启 |

### 2.5 应用服务 / 媒体 · 核心抽象
| 能力 | 状态 | 证据 |
|---|---|---|
| FileResolver(相对↔绝对+穿越拒绝) / SecureStorage(Keychain+凭据管理器+脱敏) / VideoDownload / media_kit 播放+缩略图 / AppTeardown | ✅ | 各 `lib/services/*` + DI；多数有测试 |
| media_kit 播放/缩略图单测 | ⬛ | 仅接口+实现，无 `media_kit_*_test.dart`（在覆盖率排除名单内） |
| Key 验证缓存(TTL 1h) / 文件名清理器 | ⬜ | ARCH §9.3/§6.4 标 Planned |
| InkError sealed(6 子类/15 码) + retryable 白名单 + i18n 编译期闸门 | ✅ | `ink_error.dart` + `ink_error_i18n_test.dart` |
| InkLogger(结构化 JSON + 10MB/200MB 轮转 + 敏感字段脱敏) | ✅ | `logger_service.dart`（曾有 1 个 rotation flake，与功能无关） |
| DI 全走接口（无 static singleton/ServiceLocator）+ freezed 模型 | ✅ | `lib/core/di/*` + grep 无 GetIt/static instance |

### 2.6 Studio 外壳 / Settings · 设计 Token · i18n
| 能力 | 状态 | 证据 |
|---|---|---|
| Amber Noir：frameless chrome(window_manager) + Studio Home + open-canvas + 三套主题 + 新字体 + Noir 组件 | ✅ | `ink_window_chrome.dart` / `studio_home_screen.dart` / `tokens.dart`(dark/light/highContrast) |
| Settings：Provider key 录入/验证 UI + 主题/语言/存储路径 | ✅ | `api_keys_section.dart`（按 scope 折叠）等 5 分节 |
| 移除 Lock 启动闸门(#108) → 软提示 banner | ✅ | `lib/features/lock/` 已删，`studio_provider_banner.dart` 替代 |
| `lib/features` 硬编码样式清零（vs 文档「~60 处」） | ✅ | grep `Color(0x` 在 features 0 命中 |
| en/zh key 213↔213 对齐 + 卫生守卫测试 | ✅ | `arb_hygiene_test.dart`；arb-reconciliation 死键已清 |
| 独立 ARB-parity CI workflow | ⬜ | 靠 `test/quality` 软防护，无专用 i18n CI 脚本 |

---

## 3. 设计已写、代码未建（待建账本）

| 待建项 | 出处 | grep 证据 |
|---|---|---|
| ⬜ PerformanceDegradationController / PerformanceTier / FpsMonitor | ARCH §10 | 全部 0 命中；`job_queue` 注释 `b4 ⏳ 性能档位联动` |
| 🟡 A11y 键盘完全可达（Semantics 部分覆盖 8 文件；FocusTraversal/Shortcuts 仅 1 处） | ARCH §11 | `focusRing` token ✅ 已建；键盘门禁测试 ⬜ 未写 |
| ⬜ estimateCost + 成本展示 UI | PROVIDER-API §4 | 0 命中 |
| ⬜ custom_providers.json 自定义 Provider | PROVIDER-API §13 | 0 命中 |
| ⬜ QuotaAware / ProviderQuota | ROADMAP（已删待重立项） | 0 命中 |
| ⬜ JobQueue 自动重试 + 下载续传 | ARCH §5.3 / §8 | 仅注释提及「未实现」 |

### 路线图大模块（当前范围之外）
| 模块 | 状态 | 说明 |
|---|---|---|
| Shot 节点（分镜） | 🟡 | 仅 `CanvasNodeType.shot` 模型层，Inspector 返回空，无生成逻辑 |
| 视频导出 / 剧本编辑器 / 素材库 | ⬜ | `docs/CLAUDE.md` 明列「未实现」，无代码 |
| 移动端 / Web SaaS / 闭源 license | 🚫 | 明确不做 |

---

## 4. 下一步最高杠杆动作（按离 beta 距离排序）

1. **跑绿质量基建（解锁 DoD #5）** — 手动触发 `smoke.yml` + `update-goldens.yml`，确认 Win/mac 首跑绿、golden 基线在 canonical runner 可靠。这是 beta 唯一的运行时未知。
2. **清点 P0 issue（解锁 DoD #8）** — 查 GitHub `label:P0`，确认为 0。
3. **收尾后端 P1** — DbRow 类型化最后 ~5%（Job/Canvas/Project row）+ Provider 响应解析防御(P1-4) + JobsRegistry 硬上限(P1-5d)，三项互不冲突。
4. **补 media_kit 服务单测** — 播放/缩略图当前在覆盖率排除名单里裸奔，写 Fake 补测可去排除项、抬真实覆盖率。
5. **放行 Provider 试点 fleet** — DALL-E/SD 计划已预审，fixture-E2E 卡在真 key；拿到 key 后补齐 OpenAI/Stability fixtures，把这两款从 🟡 推到 ✅。
6. **（beta 后）启动 ARCH §10 性能降级控制器** — 解 canvas >200 节点 frame drop 的运行时降级，目前只有静态护栏。
