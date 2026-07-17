# GAP-1 设置页 Custom Provider 编辑 UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 设置页可视化增删改 custom_providers.json（列表+5 字段表单+删除确认+内联校验），守住「重启生效」边界；顺带 API Keys 行对 `custom:*` 显示 displayName。

**Architecture:** 读写分离——`CustomProviderSource`（既有,registry 消费,会话内不变）不动;新增 `CustomProviderStore` 接口（fresh list/upsert/remove）,由 CustomProvidersFileService 一并实现。校验抽成 core 纯函数（服务解析与 UI 内联复用同一事实源）。写回走 raw 条目保真 + `.partial`→rename 原子盘。

**Tech Stack:** 既有 kProviderProtocolTemplates 白名单、AppPaths.config、InkCard/InkButton 组件、ARB。

## Global Constraints

- **不碰 registry 变异深水区**：会话内 configs 不变;所有写操作仅落盘,UI 常驻「重启后生效」提示。
- **写回保真（本卡最大风险面,拍板③）**：写路径重读 raw 数组,按 id 匹配替换/删除/追加;**读侧剔除的非法/未知 raw 条目原位保留**——编辑一条不销毁用户手编的坏条目。
- **损坏文件写保护（拍板④）**：文件损坏（不可解析/顶层非数组）时写操作**拒绝执行**抛 LocalIOError（绝不覆盖用户可能想抢救的文件）,UI 呈现错误。
- 原子写：`.partial`→rename;2 空格缩进 pretty JSON（保持可手编）。
- i18n：新 ARB 键 en/zh 全覆盖 + gen-l10n 同 commit。
- 校验=PROVIDER-API §13.1 全集：id 正则/唯一/不撞内置;template 白名单下拉;base_url 绝对 http(s) 无 query/fragment/userinfo;5 字段非空。

---

### Task 1: 校验纯函数抽取 + CustomProviderStore 写侧（TDD）

**Files:**
- Create: `lib/core/models/custom_provider_validation.dart`（纯函数,无 IO/Flutter）
- Create: `lib/core/interfaces/custom_provider_store.dart`
- Modify: `lib/services/custom_providers_file_service.dart`（_parseEntry 改用共享校验;实现 Store）
- Modify: `lib/core/di/providers.dart`（customProviderStoreProvider）
- Test: `test/core/models/custom_provider_validation_test.dart`、`test/services/custom_providers_file_service_test.dart`（扩写侧）

**Interfaces:**
- Produces: `CustomProviderFieldError` enum（emptyField/invalidId/duplicateId/reservedId/unknownTemplate/invalidBaseUrl）;`CustomProviderFieldError? validateId(String, {required Set<String> takenIds, required Set<String> reservedProviderIds})` / `validateBaseUrl(String)` / `validateTemplate(String)` / `validateRequired(String)`;`abstract class CustomProviderStore { Future<List<CustomProviderConfig>> list(); Future<void> upsert(CustomProviderConfig c); Future<void> remove(String id); }`
- upsert 语义：raw 数组中首个 `id` 字段==目标者原位替换,无匹配则追加;remove 同匹配删除;其余 raw 条目逐字保留。

- [ ] 红测：校验纯函数全分支;写侧=upsert 新增/替换、remove、**保真**（含一条非法 raw 条目的文件写后该条仍在）、损坏文件拒写抛 LocalIOError、原子性（.partial 不残留）、写后 fresh list 可读回。
- [ ] 实现;`flutter analyze` + 目标测试绿;commit `feat(providers): GAP-1 校验纯函数 + custom provider 写侧`

### Task 2: 设置页 CustomProvidersSection + ARB（TDD）

**Files:**
- Create: `lib/features/settings/widgets/custom_providers_section.dart`
- Modify: `lib/features/settings/settings_screen.dart`（挂载,置 API Keys 之后）
- Modify: ARB en/zh（settingsCustomProviders* ~18 键）+ generated/
- Test: `test/features/settings/custom_providers_section_test.dart`（fake Store）

**Interfaces:**
- Consumes: customProviderStoreProvider;`customProvidersListProvider = FutureProvider.autoDispose`（store.list() fresh 读,写后 invalidate）。
- 结构：标题+hint;条目行（displayName + `custom:<id>` + template 徽标 + 编辑/删除 icon）;空态文案;「Add provider」按钮;表单对话框（id 仅新增可编/编辑锁定,display_name,template 下拉,base_url,model_id;内联错误经校验纯函数);删除确认对话框;会话内发生过写操作后常驻 warning 条「重启后生效」。

- [ ] 红测：列表渲染/添加流（含 id 冲突与 base_url 带 query 内联报错不提交）/编辑流（id 锁定）/删除确认/写后 restart 条出现/store 抛 LocalIOError（损坏文件）→ 错误呈现不崩。
- [ ] 实现 + gen-l10n;全量闸门;commit `feat(settings): GAP-1 Custom Providers 编辑区`

### Task 3: API Keys 行 displayName 顺带修 + docs + PR

**Files:**
- Modify: `lib/features/settings/widgets/api_keys_section.dart`（`custom:*` 行经 providerCapabilitiesListProvider 取 displayName）
- Test: 既有 api_keys_section_test 扩一例
- Modify: docs/BOARD.md、docs/MASTERPLAN.md（GAP-1 登记,上线前清单收官宣称**须按 #198 教训如实核对**）

- [ ] displayName 测试红→绿;全量闸门;PR → 对抗评审（关注:写回保真/损坏拒写/校验双源一致/重启边界泄漏）→ 修 P1/P2 → CI 一次性核验 → squash merge。

## Self-Review

- 卡面验收逐条对齐：不碰 json 完成增删改 ✓(Task 1/2);非法输入内联报错 ✓;损坏 json 不崩 ✓(拒写+呈现);重启后下拉出现=既有 bootstrap 链天然满足 ✓;fake Source/Store widget 测试 ✓;顺带修 displayName ✓(Task 3)。
- 类型一致：CustomProviderFieldError 名称在 Task 1/2 一致;Store 三方法签名一致 ✓。
