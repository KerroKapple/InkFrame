# InkFrame 严格进度核查报告（地面真值版）

> ⚠️ **归档快照，不再更新**：本文冻结于 2026-06-29（基线 `a5ba6a0`），结论以当日为准。
> 现状唯一事实源见 [BOARD.md](BOARD.md)。
>
> 核查日期：2026-06-29 · 基线：`main @ a5ba6a0`（工作树仅 4 个 untracked docs，无 lib/ 改动）
> 方法：**先跑后审**——先实跑工具链拿地面真值，再用多 agent 编排对 2026-06-27 审计的全部 36 条发现做**对抗式逐条复核**（默认证伪），并对该审计自认的盲区做**全新独立审计**。
> 编排规模：69 个 Opus agent、3.2M token、~19 分钟（另加 1 个独立安全 agent 补盲区）。
> 与既有文档关系：本文以**实跑证据**校准 `PROGRESS.md`（claims）与 `AUDIT-REPORT.md`（静态只读，自认未跑测试）。冲突以本文为准。

---

## 0. 一句话结论

**项目比文档显示的更稳，也比审计显示的更轻。** 非 golden 测试套件首次实跑**全绿（931 通过）**、analyze 与 custom_lint 均零发现；审计标的 **2 个 P0 经对抗复核全部降级为 P2**（一个当前零用户可见影响，一个在生产路径不可达）。审计 36 条发现**无一条假阳、无一条已被悄悄修掉**——即"全是真的、但严重度普遍偏高"。**真实必修面 = 10 条 P1 + 盲区新揪出的 ~4 条 P1，外加一份现成的 P0/P1 修复计划尚未执行。**

---

## 1. 工具链地面真值（此前审计从未实跑的部分）

| 检查 | 命令 | 结果 | 判定 |
|---|---|---|---|
| 静态分析 | `flutter analyze --no-pub` | `No issues found!`（136.5s, exit 0） | ✅ DoD#1 **实跑确认** |
| 自定义 lint | `dart run custom_lint` | `No issues found!`（真实运行，非空转） | ✅ 比"非阻断"注释更干净 |
| 测试套件 | `flutter test --no-pub` | **931 通过 / 44 跳过 / 3 失败** | ✅ 非 golden 套件**全绿（首次实跑）** |
| 3 个失败 | — | 全是 `node_card_golden_test.dart`（idle/link source/selected） | ⚠️ **Windows 字体光栅化假阳性**（基线只认 canonical ubuntu，见 TESTING.md §8.3 / ci.yml）——**非回归**；侧证 golden 已接线且基线存在（DoD#3） |
| 44 跳过 | — | PG 集成测试（`TEST_PG_URL` 未设） | 本地预期，CI 用 `postgres:17-alpine` 补 |
| ARB 键集对齐 | — | 真实键集一致（由通过的 `arb_hygiene_test` 强制） | ✅（"221 vs 219" 是 @metadata 测量假象 = P2-2） |

> 含义：`PROGRESS.md` 标 `✅*`（CI 强制存在但未实跑）的 DoD #1/#2/#7 中，#1（analyze）与 #2（test，非 golden 部分）**本次已本地落地为绿**。golden 因平台原因本地无法验证，需以 CI ubuntu 为准。

---

## 2. 36 条审计发现的对抗复核判定

| 判定 | 计数 | 含义 |
|---|---|---|
| **CONFIRMED**（描述与严重度均准确） | **14** | 10 条 P1 + 4 条 P2 |
| **MISSTATED**（问题真实存在，但严重度高估） | **22** | 全部重判为 P2 |
| **FALSE_POSITIVE**（审计判断本身错） | **0** | — |
| **FIXED**（代码已不存在） | **0** | — |

**关键解读：审计零误报、零漏修——它发现的每个代码模式都真实存在。但它"宁可漏报不要误报"的保守取向导致严重度系统性偏高**，其中两个 P0 尤其失真：

### 两个 P0 双双降级为 P2（强论据）

- **P0-1（画布标题显示默认名）→ P2**：代码事实属实（`app.dart:79` 写死 `canvasDefaultName`，真实名被丢弃）。但当前**零用户可见影响**——尚无重命名 UI（`current_canvas_id.dart` 注释自认"管理 UI 后续 sprint 补"），两条建画布路径都以 `canvasDefaultName` 命名，故现存每个画布的"真实名"恰等于默认名。即便将来支持重命名，故障面也仅是顶栏面包屑显示陈旧名——无崩溃/无数据丢失。**纯展示型潜伏缺陷。**
- **P0-2（JobQueue 静默丢产物+假成功）→ P2**：代码事实属实（关键 ID 为空时 `return null` 当成功）。但该分支**在生产不可达**：① 依赖经 DI 恒注入（`job_queue.dart:25-33`）；② `canvasId` 走 `reqId`（空即抛，`generation_controller.dart:179`）；③ `resultNodeId` 在原子事务内 `scope.nodes.create` 产出；④ `projectId` 虽用 `optId`，但读路径 inner JOIN `canvases.project_id`（schema `NOT NULL`）保证行内恒有值。全仓仅一处 `queue.submit(task)`。**"静默丢产物"在任何可达生产路径都不会发生**——这是被注释明确标注的"单测便利分支"。属脆弱设计（应生产缺 ID 时报错而非静默成功），但非主动缺陷。

> 这两条仍**值得修**（见 §4 的现成计划），因为它们是脆弱设计、且修复成本极低；但它们不是"线上正在烧的火"。

---

## 3. 真实必修清单（复核后 re-graded）

### 3.1 真 P1（10 条，CONFIRMED 维持 P1）

| ID | 位置 | 问题 | 类型 |
|---|---|---|---|
| **P1-1** | `canvas_edges_controller.dart`（build 无 `_alive`/`onDispose`；L65/68/79/98 await 后写 state） | dispose 竞态写已销毁 state；头注释自称"与 nodes 对齐"实则未对齐（siblings 有守卫+回归测试） | 运行时（崩溃影响**存争议**，见 §6） |
| **P1-2** | `canvas_node.dart:139 vs 153-154` | `==` 顺序无关 / `hashCode` 顺序相关 → 破坏契约 | 正确性（潜伏，当前无 Set/Map 键用法触发） |
| **P1-5** | `core/di/database.dart:86-91` | 非 InkError（ServerException/StateError）泄漏过 DI 边界；DDL+迁移塞进纯接线 body | 错误契约+架构（**盲区审计独立复现**） |
| **P1-7** | 9 个 provider `displayName` | 英文常量直接渲染于下拉，违 i18n（非 prompt 豁免） | i18n 合规 |
| **P1-12** | `components/` vs `primitives/` | 按钮/卡片/输入两套并行重叠实现，分层意图不成立 | 架构 |
| **P1-13** | `theme/components/ink_window_chrome.dart` | theme 组件直接调 `window_manager` 平台包，违 SOLID-D | 架构 |
| **P1-16** | `media_kit_thumbnail_service.dart:21,23` | 固定 `Future.delayed(300ms)`（flaky）+ `open/seek` 无 timeout（损坏文件可能永久 await） | 运行时（flaky+挂起） |
| **P1-x2** | `job_queue_panel.dart:288-308` | `_errorMessage` 手写错误→文案映射，与 `l10nError()` 重复且**漏 `errorProviderInvalidResponse` 分支** | UI 正确性（错误文案） |
| **P1-x4** | `job_queue_service.dart` + `provider_capabilities.dart` | per-provider `pollTimeout/backoff` 字段存在但全用全局默认 → 死配置 | 配置/正确性 |
| **P1-x5** | `app_teardown.dart:43-57` | `stop()` 仅捕 `PgLifecycleError`，其余异常逃逸阻止 `container.dispose()` | 清理完整性 |

### 3.2 P2（26 条：4 条 CONFIRMED-P2 + 22 条由 P0/P1 降级）

按主题归并（全部为真实存在的纪律/一致性/微优化/防御纵深问题，逐条有 file:line，详见 `AUDIT-REPORT.md`）：
- **设计令牌纪律（根因：缺图标尺寸/控件高度两档令牌）** — P1-9↓、P2-1、theme 裸 `Color(0x00000000)`
- **错误处理纪律（catch-all 收窄）** — P1-4↓（GenerationError 游离体系/裸 catch ≥10 处）、P2-3、`secure_storage.dart:28`
- **freezed/模型纪律** — P1-8↓（canvas/studio 手写模型未登记例外）、P1-2 同源
- **数据层纪律** — P1-11↓（SQL 列名/表名插值无白名单，当前不可利用）、P2-4（columns 常量未贯穿）
- **Provider 能力对齐** — P1-14↓（maxRefImages 未 take/batchSize 未 clamp/async submit 不校验）、P1-x1↓（listCapabilities 强实例化全 9 provider）
- **死代码/重复/stub** — P1-10↓（僵尸 `canvas_node_card.dart`+同名枚举）、P1-17↓（_PromptPreview 重复拼装）、P1-18↓（JobRepository 胖接口）、P1-x3↓（ARCHIVE/footer 死 stub）、P1-x6↓（unsafe `as String?`）、P1-x7↓（addEdge 死回滚分支+误导注释）、P2-8、P2-6、P2-9
- **i18n 边界 / 测试质量 / 安全防御纵深** — P2-2、P2-7、**P2-5（CONFIRMED：symlink 边界/PG stderr 入异常/脱敏正则漏 token 格式）**

---

## 4. 现成的修复计划（尚未执行）

`docs/superpowers/plans/2026-06-27-correctness-hardening.md` 已把 P0-1/P0-2 + P1 正确性簇（edges `_alive`、hash/equals、unsafe cast、N+1、非事务 reorderLanes）拆成 **7 个 TDD 任务**，每任务自带失败测试→实现→提交步骤、且生产代码已逐字校验。**全部任务未执行**（复选框全空，git log 无对应 commit）。这是把上面 P1/P2 转化为绿色提交的最短路径。

> 注：该计划把 P0-1/P0-2 当 P0 修——按本次复核它们其实是 P2，但**仍建议修**（脆弱设计、成本低）。计划内的 P1-1（edges `_alive`）/ N+1 / reorderLanes 是真 P1，优先级最高。

---

## 5. 盲区新发现（审计自认未覆盖，本次全新独立审计揪出）

### 5.1 无障碍 / a11y（审计因预算耗尽完全未做 → 6 条全部复核为真）
- **【P1】自建交互组件全部基于 `GestureDetector/Listener`，键盘不可聚焦、不可激活、无焦点指示**（`ink_amber_button`/`ink_ghost_button`/`ink_noir_card`/`ink_window_chrome`/`studio_top_chrome`/`library_sidebar`）——**系统性 a11y 缺口**。
- **【P2】核心画布面板纯指针操作**，节点无 `Semantics`、选中态仅靠边框色、无键盘快捷键（`node_card`/`canvas_view`）。
- 【P2】单选按钮组（主题/语言/项目树）选中态只用视觉变体，未暴露语义层。
- 【P2】弱前景 token `fg4` 承载活动文本，明/暗主题下对比度 **低于 WCAG AA**（`tokens.dart`/`job_queue_panel`）。
- 【P2】文本输入框只有 `hintText`、缺可编程标签，输入后失去无障碍名称。
- 【P2】`ink_surface_button`/`ink_accent_chip`/`ink_dashed_slot` 三原语无 `Semantics(button)`。

### 5.2 theme 层深读（6 条全部复核为真）
- **【P1】`app_theme.dart:71-73` 把 `ColorScheme.onPrimary/onSecondary` 误设为 `fg1`（前景文本色）** → 暗色/高对比主题下 Material `FilledButton` 标签几乎不可读。**真视觉 bug。**
- 【P2】死代码 4 处：`InkTypography.code`（零消费）、`InkTypography.scaled()/_scale()`（重复且死）、`InkMotionSpring`（仅测试引用）、`InkShadow.overlay`（零引用死令牌）——违"不保留 just-in-case 废弃 API"。
- 【P2】`ink_button.dart:29` 裸 `Color(0x00000000)` 代替 `Colors.transparent`。

### 5.3 全新正确性 bug（审计整体漏掉，复核为真）
- **【P1】乐观新增的丢更新竞态**：并发 `addNode`/`addEdge`/`createLane` 各自基于进入时快照 `previous` 重建列表 → 互相覆盖（lost-update）。
- **【P1/P2】同步 Provider `base64Decode` 未捕获 `FormatException`**（`sync_provider_base.dart`）→ 违背 "解析失败抛 `ProviderError`" 契约，畸形 base64 直接逃逸为未分类异常。
- 【P2】`reorderLanes` 非原子多写（= 审计 P1-6，独立复现，复核 P2）。

### 5.4 依赖卫生（4 条全部复核为真，可直接清理）
| 依赖 | pubspec | 结论 |
|---|---|---|
| `riverpod_annotation` | :18 | **可移除**（lib 零用；DI 全手写 Provider 非 codegen）+ 连带 dev `riverpod_generator` |
| `json_annotation` | :22 | **可移除**（lib 零用；core/models 无 toJson/fromJson）+ 连带 dev `json_serializable` |
| `logging` | :28 | **可移除**（自有 `logger_service`，lib 零 import） |
| `uuid` | :41 | **可移除**（主键由 PG `gen_random_uuid` 生成，lib 零 import；仅测试用→应移 dev） |

> 注：`cupertino_icons`（纯资产）、`media_kit_libs_video`（原生 libs）零 import 属正常，**不在可移除之列**。

---

## 6. 验证冲突与诚实声明

1. **P1-1 存在判定冲突（需点名）**：Stream A 复核判 **CONFIRMED（真 StateError 崩溃，P1）**；Stream B（fresh-correctness）独立复核判 **isReal=false**，理由是"实查 riverpod 2.6.1 源码，dispose 后写 state 不抛"。
   **裁决**：客观事实无争议——edges 控制器**确实缺**了 nodes/lanes 都有的 `_alive` 守卫，且头注释谎称"已对齐"（我已第一手核验 L1-102）。**争议仅在崩溃后果**（取决于 riverpod 2.6.1 内部实现）。鉴于团队自己用 ME-27 模式+回归测试封堵过同类，且修复**零成本、最坏情况只是无害硬化**，结论：**照修**（恢复声称的一致性），无需先解决 riverpod 行为之争。
2. **盲区有一处未覆盖**：`fresh-security`（全新独立安全扫）finder agent 因 server 限流**整体失败**——见 §7 补测（已用独立 agent 补跑）。`underread-di-core` 的 4 条发现其 confirm 阶段限流失败（未经二次复核），但其中 #1/#3 与已 CONFIRMED 的 P1-5/P1-4 重叠、#2 与架构梳理一致，故视为已佐证；#4（`loggerProvider` onDispose 注释声称 close 释放句柄但 `close()` 是 no-op）为新的小瑕疵，未独立复核。
3. **本次为静态+测试核查**：运行时/视觉/golden 像素/并发竞态的真实运行时行为未动态验证（golden 本地 Windows 必假阳）。§5.3 的丢更新竞态为静态推断的真 bug。
4. **审计 §5 的语言新特性误报教训已规避**：本次所有 agent 预置 Dart 3.11 null-aware 集合语法说明，未复现"合法语法误判语法错误"。

---

## 7. DoD 真实记分卡（基于地面真值）

| # | DoD | PROGRESS.md 标 | 本次实跑判定 |
|---|---|---|---|
| 1 | `flutter analyze` 干净 | ✅* | ✅ **本地实跑确认** |
| 2 | `flutter test` 全绿 | ✅* | ✅ 非 golden 部分**实跑全绿**；golden 需 CI ubuntu |
| 3 | Golden 基线 + CI 校验 | ✅ | ✅ 基线存在已侧证 |
| 4 | ≥1 E2E 主链路 | ✅ | ✅（E2E 在 931 通过内） |
| 5 | Win+mac 双烟测 | 🟡 | 🟡 仍待 CI 实跑（人工触发 `smoke.yml`） |
| 6 | 性能基线文档化 | ✅ | ✅ |
| 7 | 覆盖率 ≥70% | ✅* | ❓ 本地未单跑 `--coverage`；CI `very_good_coverage` 强制（CI 绿即达标） |
| 8 | 无 P0 open bug | ❓ | ✅（代码侧）**真实 P0 = 0**（两个标的 P0 经复核降级）；GitHub `label:P0` 仍需人工清点 |

**结论：代码侧无 beta 阻塞项；剩余为运行时确认（smoke CI 首跑）+ issue 清点两件人工事，与 PROGRESS.md 判断一致——但本次把"真实 P0=0"从推测升级为带论据的复核结论。**

---

## 8. 建议下一步（按杠杆排序）

1. **执行现成的 `correctness-hardening` 计划（7 任务 TDD）** — 一次性消化 P0-1/P0-2（脆弱设计）+ P1-1（edges `_alive`，连带修 P1-x7 死回滚/误导注释）+ hash/equals + unsafe cast + N+1 + 非事务 reorderLanes。**适合跨隔离 worktree 并行执行**（每任务独立文件域，互不冲突）——这才是 worktree 真正发挥隔离价值的地方。
2. **补 §5.3 两个全新真 bug** — 乐观更新丢更新竞态 + `base64Decode` 未包 `ProviderError`（计划未覆盖，应新增任务）。
3. **修 §5.2 的 `onPrimary/onSecondary` 视觉 bug + §5.1 的 a11y P1** — 用户可见/可达性，成本低。
4. **清依赖（§5.4）** — 移除 `riverpod_annotation`/`json_annotation`/`logging`/`uuid`（+2 dev 连带），瘦身且消歧"是否用 codegen"。
5. **补两档设计令牌（图标尺寸/控件高度）** — 这是 P2 中 8+ 条裸数字的共同根因，一改清一片。
6. **人工事**：触发 `smoke.yml`/`update-goldens.yml` 确认 Win/mac 首跑绿（DoD#5）；清点 GitHub `label:P0` issue（DoD#8）。

---

## 附：安全盲区补测（已完成）

`fresh-security` 在主编排中因限流失败，已用独立 agent 补跑（覆盖生成控制器/JobQueue 下载落盘/PG 生命周期/迁移器/DI/错误·日志序列化全链路）。

### 新增安全发现

- **【P2，多用户机器升 P1】嵌入式 PostgreSQL 用 `trust` 认证 + 回环 TCP 暴露超级用户**
  - 证据：`pg_controller.dart:71-77`（initdb 固定 `-A trust`）；`:87-90`（`listen_addresses=127.0.0.1` + 关 Unix socket，仅 TCP 回环）；`database.dart:58-68`（user `inkframe`、无密码、`SslMode.disable`）；端口明文写 `~/InkFrame/config/pg.port`。
  - 影响：本机**任何**进程/其他 OS 用户都能免密以超级用户 `inkframe` 连 `127.0.0.1:<port>`，进而 `COPY ... TO/FROM PROGRAM` 以登录用户身份**任意代码执行/任意文件读写**。
  - 现实风险：单用户桌面需"已有本机敌对/低权进程"才成立 → **P2**；但它把任何无代码执行的本机落脚点直接提权，**共享/多用户机器或面对低完整性沙箱进程时是真实 P1**。**不在既有清单内，属新问题。**
  - 修法方向：改 `scram-sha-256` + 随机密码存 SecureStorage；或仅用 Unix socket + peer 认证（Windows 仍需密码）。
- **【P2，低置信】同步图片 Provider 无响应体大小上限（OOM）**：`sync_provider_base.dart:176-184` Dio 未设响应上限，gemini/openai 整体缓冲 JSON 后 `base64Decode`；而异步视频路径有 2 GiB 闸（`dio_video_download_service.dart:19,46`）。超大/MITM 响应可致本进程 OOM（仅自伤，TLS+可信端点，低风险纵深项）。

### 对审计 P2-5 的修正（对抗复核澄清）

- **签名 URL 脱敏盲点不成立**：`InkError.toString()`（`ink_error.dart:98`）只输出 code/retryable、**不含 extra**；`toLogJson()` 定义了但**全代码零调用点**，DB `error_message` 只存 `error.toString()`。故 DashScope 签名 OSS 产物 URL（含 `OSSAccessKeyId`/`Signature`）**既不进日志也不进 DB**——P2-5 的"脱敏正则漏 token 格式"对**已落地的日志路径**实际不可达（脱敏正则本身的覆盖面仍可加固，但泄漏面比审计描述的小）。

### 已逐项证伪（确认非问题，无需修）

凭据全走请求头（Gemini 校验不带 key）、路径穿越经 resolver 边界校验、SQL 全 `Sql.named` 绑定（列名插值键全内部常量）、`Process.run` 用参数数组无 shell 注入、下载仅 https + 2 GiB + content-type 拒绝（无实际 SSRF）、provider JSON 解析有 `is! Map`/`is! List` 守卫 + 外层兜 `UnknownError`。

> **安全总评**：本地优先单用户桌面威胁模型下，**无高危项**。最值得修的是 PG `trust` 认证（共享机器场景 P1）；其余为低风险防御纵深。
