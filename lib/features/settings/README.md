# features/settings

设置界面：API Key、主题、语言、存储、关于。

> 相关 ADR：[0010 i18n/token 零硬编码](../../../docs/adr/0010-zero-hardcoding-i18n-and-design-tokens.md) · [0002 Riverpod 状态/DI](../../../docs/adr/0002-riverpod-for-state-and-di.md) · [0001 嵌入式 PostgreSQL（存储路径）](../../../docs/adr/0001-embedded-postgresql.md)

## 组成

```
settings_screen.dart                整屏容器
widgets/api_keys_section            每个 provider 的 Key：保存/清除/校验（经 SecureStorageService）
widgets/theme_section               深色 / 浅色 / 高对比 + 字号缩放
widgets/language_section            English / 中文
widgets/storage_path_section        数据库目录展示 + 复制路径
widgets/about_section               应用/版本/安全存储后端探测
providers/api_key_scope_controller  API Key 输入/校验的作用域状态
```

## 关键点
- **API Key 只经 `SecureStorageService` 接口**（macOS Keychain / Windows Credential Manager）——绝不落代码/配置/DB。保存时可触发 provider 端校验，返回 已保存/未验证/被拒 三态（`settingsApiKey*` l10n）
- 主题切换驱动 `buildAppTheme(variant, textScale)`（三套变体 + a11y 缩放，ADR-0010）
- 存储目录本版本固定（`settingsStorageReadOnlyHint`），迁移流程见 ROADMAP

## 约束
- 文案全部 `context.l10n.settings*`（en/zh 键集一致，CI 校验）；样式 token 化（ADR-0010）
