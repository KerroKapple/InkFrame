# features/settings

设置界面：API Key、主题、语言、存储、关于。

> 相关 ADR：[0010 i18n/token 零硬编码](../../../docs/adr/0010-zero-hardcoding-i18n-and-design-tokens.md) · [0002 Riverpod 状态/DI](../../../docs/adr/0002-riverpod-for-state-and-di.md) · [0001 嵌入式 PostgreSQL（存储路径）](../../../docs/adr/0001-embedded-postgresql.md)

## 组成

```
settings_screen.dart                浮层对话框（Screens 稿第 3 屏）：40 标题栏 | 左导航 200 + 页 | 44 底部条；
                                    自持焦 + Esc；页 = 常规 / API 密钥 / 节点布局 / 存储 / 关于
providers/settings_page             当前停在哪一页（keepAlive：关掉再开回到上次那页）
widgets/api_keys_section            API Key 表（Provider | Key | 状态）：按 SecureStorageKeys.scopeOf 折叠为每 scope 一行
                                    （DashScope 家族 6 款合一行）；保存/清除/校验（经 SecureStorageService）
widgets/custom_providers_section    自定义 OpenAI 兼容服务商（custom_providers.json）
widgets/theme_section               深色 / 浅色 / 高对比 + 字号缩放（常规页）
widgets/language_section            English / 中文（常规页）
widgets/startup_section             启动时打开上次的画布（常规页，语言下面；稿上没有的新增行）
widgets/canvas_appearance_section   连线 / 卡片颜色（节点布局页）
widgets/storage_path_section        数据库目录展示 + 复制路径（存储页）
widgets/backup_section              备份 / 还原（存储页）
widgets/about_section               应用/版本/安全存储后端探测（关于页）
widgets/diagnostics_section         日志目录 + DiagnosticsExportButton（关于页；底部条也放一枚）
providers/api_key_scope_controller  API Key 输入/校验的作用域状态
```

稿上的「快捷键 / 性能 / 网络」没有可配置字段，不画；「区域」列、「已验证 / 余额不足 / 连接失败」
状态、Key 尾 4 位、「全部重新验证」、并发与配额滑杆同样无后端，不画（PR #235 列了清单）。

## 关键点
- **API Key 只经 `SecureStorageService` 接口**（macOS Keychain / Windows Credential Manager）——绝不落代码/配置/DB。保存时可触发 provider 端校验，返回 已保存/未验证/被拒 三态（`settingsApiKey*` l10n）
- Key 行集来源 `providerCapabilitiesListProvider`（内置 const + `custom_providers.json` 模板派生的合并列表）——新增 custom provider 零改动自动多一行
- 主题切换驱动 `buildAppTheme(variant, textScale)`（三套变体 + a11y 缩放，ADR-0010）
- 存储目录本版本固定（`settingsStorageReadOnlyHint`），迁移流程见 ROADMAP

## 约束
- 文案全部 `context.l10n.settings*`（en/zh 键集一致，CI 校验）；样式 token 化（ADR-0010）
