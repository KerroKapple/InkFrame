<!--
  谢谢提 PR。InkFrame 有强一致性的工程纪律（CONTRIBUTING.md / docs/ARCHITECTURE.md），
  请把下面的清单认真过一遍，能大幅减少来回。
-->

## 这是什么

<!-- 一两句话说明这个 PR 在解决什么问题 -->

Closes #<!-- 关联 issue -->

## 改动类型

- [ ] 🐛 Bug fix
- [ ] ✨ 新功能
- [ ] 🔌 新 AI Provider 适配器
- [ ] 🎨 UI / 主题
- [ ] ♻️ 重构（不改外部行为）
- [ ] 📝 文档
- [ ] 🗄 数据库 schema 变更（带 migration）
- [ ] ⚙️ 工程 / CI / hooks
- [ ] 💥 破坏性变更

## 自查清单

- [ ] `flutter analyze` 0 warning（CI 强制）
- [ ] `flutter test` 全部通过
- [ ] `flutter test --tags=golden`（如改了视觉）
- [ ] **i18n 完整性**：新增的 user-facing string 在 `app_en.arb` 和 `app_zh.arb` 同时落地
- [ ] **零硬编码**：颜色 / 字号 / 间距走 `lib/theme/tokens.dart`，不在 widget 里 `Color(0xFF...)`
- [ ] **DI 正确性**：服务通过 Riverpod provider 注入，未引入静态 singleton 或 ServiceLocator
- [ ] **错误类型化**：未捕获 `Exception` / `dynamic`，使用 domain-specific exception
- [ ] 改了 schema：附带 `lib/storage/schema/schema_vN.dart` migration，覆盖测试
- [ ] 改了 Provider：阅读 `docs/PROVIDER-API.md`，遵守适配器契约
- [ ] commit messages 走 Conventional Commits（feat/fix/refactor/test/docs/chore...）

## 截图 / 录屏（UI 改动必填）

<!-- 把图片或视频拖到这里。深色 + 浅色主题各贴一张 -->

## 给 reviewer 的话

<!-- 想让 reviewer 重点看哪一段？哪里不确定？哪里需要讨论？ -->

## 测试如何验证

<!-- 你怎么测的？覆盖了哪些边界？(如适用：手动回归步骤 / golden baseline / 集成测) -->
