# Custom Providers (OpenAI-compatible) 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户在设置页自助添加任意 OpenAI-compatible provider（OpenRouter / DeepSeek / 月之暗面 / SiliconFlow / Together / Groq / 本地 vLLM/Ollama 等），零代码扩展模型接入面，每条记录自带 base_url + api_key + model_id + 用户填写的 capabilities。

**Non-goals (本 sprint 不做):**
- Anthropic / Gemini 专属协议适配器（落地 OpenAI-compatible 验证架构后下个 sprint 加）
- 视频/异步任务的自定义 provider（alpha 阶段视频走内置）
- 跨 provider 自动 fallback / 模板库 / capabilities 预置（用户填，自由度高、错配率也高，文档警示即可）

**Architecture decisions:**
- ProviderRegistry 从启动期 `const Map` 改为**运行期动态**：内置 const 注册 ∪ Postgres 自定义注册，变更走 stream invalidation
- API key 仍走 secure storage，命名空间 `custom_provider:<uuid>` 与内置 provider key 隔离
- ProviderCapabilities 保留 freezed 形态——const 工厂在运行时也可构造非 const 实例，无需重构模型层
- 自定义 provider 仅实现 `Submittable + KeyValidatable`（同步生成），不实现 `Pollable / Cancellable`

**Tech Stack:** Flutter Desktop, Riverpod, freezed, dio, Postgres embedded, flutter_secure_storage. 详见 `docs/CLAUDE.md` / `docs/PROVIDER-API.md`.

---

## 文件结构

| 状态 | 路径 | 职责 |
|---|---|---|
| Create | `lib/core/models/custom_provider_config.dart` | freezed model：id / display_name / base_url / model_id / modality / capabilities |
| Create | `lib/storage/schema/custom_providers.sql` | DDL + schema version bump |
| Create | `lib/storage/repositories/postgres_custom_provider_repository.dart` | CRUD + stream |
| Create | `lib/storage/repositories/custom_provider_repository.dart` (interface in core) | abstract repository contract |
| Create | `lib/providers/openai_compatible_provider.dart` | dio adapter：`/v1/chat/completions` + `/v1/images/generations` |
| Modify | `lib/providers/provider_registry.dart` | 注册表改可变 + watch repository stream |
| Modify | `lib/core/di/providers.dart` | 启动期 merge 内置 + 自定义两份来源 |
| Create | `lib/features/settings/providers/custom_providers_controller.dart` | 增删改 + 验 key Riverpod controller |
| Create | `lib/features/settings/widgets/custom_providers_section.dart` | 设置页"自定义模型"分节 UI |
| Create | `lib/features/settings/widgets/custom_provider_form.dart` | 增/改弹窗表单 |
| Modify | `lib/features/settings/settings_screen.dart` | 加入 CustomProvidersSection |
| Modify | `lib/l10n/app_en.arb` / `app_zh.arb` | 新增 `customProviders*` keys |
| Modify | `docs/PROVIDER-API.md` §13 "自定义 Provider 扩展点" | 文档化协议契约 + 用户填写说明 |
| Create | `test/core/models/custom_provider_config_test.dart` | model 序列化 |
| Create | `test/storage/repositories/postgres_custom_provider_repository_test.dart` | repo CRUD |
| Create | `test/providers/openai_compatible_provider_test.dart` | adapter HTTP + 错误映射 |
| Create | `test/features/settings/custom_providers_section_test.dart` | widget |

---

## Task 1: CustomProviderConfig model + Postgres 表 + repository

**Files:**
- Create: `lib/core/models/custom_provider_config.dart`
- Create: `lib/core/interfaces/custom_provider_repository.dart`
- Create: `lib/storage/schema/custom_providers.sql`
- Create: `lib/storage/repositories/postgres_custom_provider_repository.dart`
- Modify: `lib/storage/schema/schema_version.dart` (bump)
- Modify: `lib/storage/migrations/migration_runner.dart` (apply DDL)
- Test: `test/core/models/custom_provider_config_test.dart`
- Test: `test/storage/repositories/postgres_custom_provider_repository_test.dart`

**Schema:**
```sql
CREATE TABLE custom_providers (
  id            UUID PRIMARY KEY,
  display_name  TEXT NOT NULL,
  base_url      TEXT NOT NULL,
  model_id      TEXT NOT NULL,
  modality      TEXT NOT NULL CHECK (modality IN ('text', 'image')),
  capabilities  JSONB NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX custom_providers_modality_idx ON custom_providers(modality);
```

**Model:**
```dart
@freezed
abstract class CustomProviderConfig with _$CustomProviderConfig {
  const factory CustomProviderConfig({
    required String id,
    required String displayName,
    required String baseUrl,
    required String modelId,
    required CustomProviderModality modality,
    required ProviderCapabilities capabilities,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CustomProviderConfig;

  factory CustomProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$CustomProviderConfigFromJson(json);
}

enum CustomProviderModality { text, image }
```

**Repository interface:**
```dart
abstract class CustomProviderRepository {
  Stream<List<CustomProviderConfig>> watchAll();
  Future<List<CustomProviderConfig>> listAll();
  Future<CustomProviderConfig> create(CustomProviderConfig config);
  Future<void> update(CustomProviderConfig config);
  Future<void> delete(String id);
}
```

- [ ] **Step 1: 写失败测试** — model 序列化 round-trip + repository CRUD 契约（mock DB）
- [ ] **Step 2: 落 freezed model + DDL + repository**
- [ ] **Step 3: 接 DI** (`lib/core/di/repositories.dart` 加 `customProviderRepositoryProvider`)
- [ ] **Step 4: build_runner + 测试通过**

**Verification:**
```powershell
flutter test test/core/models/custom_provider_config_test.dart test/storage/repositories/postgres_custom_provider_repository_test.dart
```

---

## Task 2: OpenAICompatibleProvider 适配器

**Files:**
- Create: `lib/providers/openai_compatible_provider.dart`
- Test: `test/providers/openai_compatible_provider_test.dart`

**协议接入点：**
- 文本/聊天: `POST {baseUrl}/chat/completions`，body `{model, messages: [{role, content}], stream: false}`，header `Authorization: Bearer <key>`
- 图像: `POST {baseUrl}/images/generations`，body `{model, prompt, n, size}`
- key 验证: `GET {baseUrl}/models`（OpenAI 协议通用端点）

**实现：**
```dart
class OpenAICompatibleProvider implements Submittable, KeyValidatable {
  OpenAICompatibleProvider({
    required this.config,
    required this.apiKey,
    required this.dio,
    required this.rateLimiter,
  });

  final CustomProviderConfig config;
  final String apiKey;
  final Dio dio;
  final RateLimiter rateLimiter;

  @override
  ProviderCapabilities get capabilities => config.capabilities;

  @override
  Future<JobId> submit(GenerationTask task) async {
    await rateLimiter.acquire();
    // 路由：modality=image → /images/generations
    //       modality=text  → /chat/completions（结果存为 ResultNode payload.text）
    // 同步 provider 直接在 submit 内拉到结果，写入 NodeRepository，返回 "local://<uuid>"
  }

  @override
  Future<KeyValidationResult> validateApiKey(String key) async {
    // GET /models，成功 → ok；401 → invalid；其它 → unknown
  }
}
```

**错误映射：** dio 异常走 `dio_error_mapper.dart`（已存在），新增 OpenAI-specific 错误码（`insufficient_quota` / `invalid_api_key` / `model_not_found` / `context_length_exceeded`）映射到 `InkErrorCode` 现有 14 错误码。

- [ ] **Step 1: 写失败测试** — mock dio，覆盖 submit 成功 / 401 / 429 / model_not_found / network timeout
- [ ] **Step 2: 落 adapter + 错误映射**
- [ ] **Step 3: 拉通 RateLimiter**（自定义 provider 共用一个 limiter，避免一家 burst 影响另一家——用 `(providerId, baseUrl)` 作为 bucket key）

**Verification:**
```powershell
flutter test test/providers/openai_compatible_provider_test.dart
```

---

## Task 3: ProviderRegistry 改运行期动态

**Files:**
- Modify: `lib/providers/provider_registry.dart`
- Modify: `lib/core/di/providers.dart`
- Test: 现有 `test/providers/provider_registry_test.dart` 加 dynamic-register / unregister 用例

**改动要点：**
1. `_entries` 从 `Map.unmodifiable` 改为可变 `Map<String, ProviderFactory>`
2. 新增 `void register(String id, ProviderFactory factory)` / `void unregister(String id)`，同 id 二次 register 抛 StateError（避免 silent override）
3. 新增 `Stream<void> get changes` 用于 UI 失效（每次 register/unregister 推一次 tick）
4. `providerRegistryProvider`（in DI）改为 watch `customProviderRepositoryProvider.watchAll()`，diff 后调 register/unregister
5. **关键不变量**：内置 provider（gemini / kling / wanx 系）永远不被 unregister，只动 `custom_provider:*` 命名空间

- [ ] **Step 1: 写失败测试** — registry register/unregister + 内置 provider 不可删 + changes stream 触发
- [ ] **Step 2: 改 registry 实现**
- [ ] **Step 3: 改 DI provider 接 repository.watchAll()**

**Verification:**
```powershell
flutter test test/providers/
```

---

## Task 4: CustomProvidersController + verify-key 流程

**Files:**
- Create: `lib/features/settings/providers/custom_providers_controller.dart`
- Test: `test/features/settings/custom_providers_controller_test.dart`

**职责：**
- `list` — watch repository.watchAll()
- `create(CustomProviderConfig)` — 写 repo + 写 secure storage（key 名 `custom_provider:<id>`）
- `update` / `delete` — 同步对齐 secure storage
- `validateKey(config, apiKey)` — 构造临时 OpenAICompatibleProvider 调 validateApiKey，不写库

- [ ] **Step 1: 写失败测试**（mock repo + mock secure storage）
- [ ] **Step 2: 实现 controller**

---

## Task 5: 设置页 CustomProvidersSection + 表单

**Files:**
- Create: `lib/features/settings/widgets/custom_providers_section.dart`
- Create: `lib/features/settings/widgets/custom_provider_form.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Test: `test/features/settings/custom_providers_section_test.dart`

**UI 形态：**
```
┌─ Custom Models ─────────────────────────────────┐
│  我的 OpenRouter   gpt-4o-image    [验证] [✏] [✕] │
│  本地 vLLM         llama-3.1-70b   [验证] [✏] [✕] │
│  [+ Add Custom Model]                            │
└──────────────────────────────────────────────────┘
```

**Form 字段：**
- Display name (text)
- Base URL (text, 含校验 `https?://`)
- Model ID (text)
- Modality (radio: text / image)
- API Key (password input，写入时走 secure storage)
- Capabilities 折叠区（用户填）：
  - region (radio cn/global)
  - supported aspect ratios (chip multi-select)
  - supported resolutions (chip multi-select)
  - max batch size (number)
  - supportsBatch / supportsSeed / supportsNegativePrompt (switches)
  - costModel (perCall amount, currency)
  - qps / burst / maxConcurrentJobs (number)
- 表单底部 [Validate Key] 按钮 → controller.validateKey

**用户填错的兜底：** 文档警示 "Capabilities 错填会导致 UI 渲染异常或限流失效"，不做强校验（自由度优先）。

- [ ] **Step 1: 写 widget 测试**（增删改 / 验 key 按钮）
- [ ] **Step 2: 实现 Section + Form**
- [ ] **Step 3: 接入 SettingsScreen**

---

## Task 6: Inspector provider 下拉接动态 registry

**Files:**
- Modify: `lib/features/canvas/widgets/image_config_inspector.dart`
- Modify: `lib/features/canvas/widgets/video_config_inspector.dart`（视频 inspector **不展示** custom provider，filter 掉 modality=text/image-only 项）

**改动：** `providerCapabilitiesListProvider` 从 const list 改为 watch `providerRegistryProvider`，registry 变更时 inspector 下拉自动刷新。

- [ ] **Step 1: 改 provider list 数据源**
- [ ] **Step 2: 视频 inspector 过滤掉 custom**

---

## Task 7: i18n + 文档

**Files:**
- Modify: `lib/l10n/app_en.arb` / `app_zh.arb` 加 `customProvidersSection / customProviderAdd / customProviderEdit / customProviderDelete / customProviderValidate / customProviderValidateSuccess / customProviderValidateFailed / customProviderFormDisplayName / customProviderFormBaseUrl / customProviderFormModelId / customProviderFormModality / customProviderFormCapabilities / customProviderModalityText / customProviderModalityImage` 等
- Modify: `docs/PROVIDER-API.md` §13 "自定义 Provider 扩展点" 落地
- Modify: `ROADMAP.md` 把 OpenAI / DeepSeek / OpenRouter 等从 "Help Wanted" 表里移除（已被自定义 provider 吃掉）

- [ ] **Step 1: ARB 双语 parity 落盘 + `flutter gen-l10n`**
- [ ] **Step 2: PROVIDER-API.md §13 写完整契约**
- [ ] **Step 3: ROADMAP.md 更新**

---

## 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| 用户填错 capabilities 导致 UI 崩溃 | 中 | Inspector 渲染加 try/catch，错误时降级为"该 provider 配置异常，请回设置页检查"提示 |
| 同步生成在 submit 内阻塞 UI 线程 | 中 | dio 本就异步，但响应大时（图像 base64）需要在 isolate 解码——Task 2 自测时验证 |
| API key 泄露到日志 | 高 | 已有 logger 的 redact 列表（password / proxy_password / secret），加 `api_key` / `authorization` 关键字 |
| 自定义 provider 覆盖内置 id | 高 | registry.register 检测内置 id（保留 `gemini-image / kling-v3 / wanx-*` 等），冲突抛 StateError |
| Postgres 表 migration 失败 | 高 | schema_version bump + DDL 走现有 MigrationRunner，失败时启动期阻塞并提示 |

---

## Done criteria

- [ ] 用户能在设置页添加一个 OpenRouter 模型（填 base_url=`https://openrouter.ai/api/v1` + model_id + key），点验证返回 ok
- [ ] 该模型出现在 Canvas 图像 inspector 的 provider 下拉里
- [ ] 选中该 provider + 填 prompt + 点 Generate，能拉回真实生成结果并落库
- [ ] 删除该自定义 provider 后下拉里立即消失，对应 secure storage key 同步清除
- [ ] 所有 i18n keys en/zh parity
- [ ] `flutter test` 全绿
- [ ] PROVIDER-API.md §13 与实现一致

---

## 后续 sprint 占位（不在本计划范围）

- AnthropicProvider 适配器（claude.ai 协议）
- 模板库（`templates/gpt-4o-image.json` 等社区贡献）
- 跨 provider 自动 fallback（capability 等价矩阵 + 策略）
- 视频自定义 provider（Kling-compatible / Runway-compatible 协议）
