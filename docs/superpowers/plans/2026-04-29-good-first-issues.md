# Good First Issue 候选 — 2026-04-29

> 5 条候选，每条都是单文件 / 30min-2h 可完成、不依赖未公开内部知识的入门任务。
> public 之后用 `gh issue create` 批量创建。

---

## #1: Add `.editorconfig` for consistent IDE indentation

**Labels:** good first issue, chore
**Estimated effort:** 30 min
**Files:** `.editorconfig` (new)
**Skill required:** EditorConfig syntax basics

### Background
InkFrame 当前没有 `.editorconfig`。不同 IDE / 编辑器（VS Code / Android Studio / Vim）默认缩进策略不一致，新贡献者第一次提 PR 容易因为 tab/space 或 trailing whitespace 触发 hook 失败。

### What to do
1. 在 repo 根目录创建 `.editorconfig`
2. 配置：UTF-8 / LF / 末尾换行 / Dart & YAML 2 空格 / Markdown 保留 trailing whitespace（hard line break 语义）
3. 在 README "Development" 段落简短提一句 IDE 会自动 pick up

### Acceptance criteria
- [ ] `.editorconfig` 文件落到根目录
- [ ] 主流 IDE 打开任意 .dart 文件 indent 自动 2 空格
- [ ] CI 全绿
- [ ] PR 走 CONTRIBUTING.md 流程

### Hints
- 参考 [Flutter SDK 自己的 .editorconfig](https://github.com/flutter/flutter/blob/master/.editorconfig)
- Markdown 部分如不确定怎么写，问维护者

---

## #2: README — add a Quickstart section for first-time builders

**Labels:** good first issue, docs
**Estimated effort:** 1 h
**Files:** `README.md`, `README.zh-CN.md`
**Skill required:** Markdown / Flutter dev env basics

### Background
当前 README 直接进 architecture，缺一个"5 分钟跑起来"的 Quickstart 段落。新人看到的是 449 行的技术文档，劝退第一印象。

### What to do
1. 在 README "Table of Contents" 之后、第一个技术段之前插入 `## Quickstart` 段落
2. 内容：clone → flutter pub get → 配 PostgreSQL（链 `docs/SETUP.md` 详版）→ flutter run -d macos / windows
3. 中英两版同步
4. 验证两版字段顺序一致（CONTRIBUTING 路径修正后所有 README 改动均双语同步）

### Acceptance criteria
- [ ] 英文版 + 中文版各加 Quickstart 段
- [ ] 段落 ≤ 30 行（不喧宾夺主）
- [ ] 链接到现有 SETUP / docs 不重复
- [ ] CI 全绿

### Hints
- 参考其他 Flutter 桌面 OSS 项目的 Quickstart 写法（如 AppFlowy）
- 不要在 Quickstart 里复制 docs/SETUP.md 全文，链过去就好

---

## #3: `app_zh.arb` — native-Chinese review pass

**Labels:** good first issue, i18n
**Estimated effort:** 1-2 h
**Files:** `lib/l10n/app_zh.arb`
**Skill required:** native or near-native Mandarin Chinese reading

### Background
当前 `app_zh.arb` 全部由维护者一人翻译（母语中文，但难免硬翻味）。需要另一位中文母语者扫一遍，标出"翻译腔"明显或机器翻译感的 key。

### What to do
1. 通读 `lib/l10n/app_zh.arb` 所有 key 的中文 value
2. 对每个明显有问题的 key，在 PR 描述里给出：原 value / 建议 value / 理由（≤ 1 句）
3. 不需要全改，每条建议都 inline 提
4. 维护者会在 PR review 里挑一批合并

### Acceptance criteria
- [ ] PR 描述列出 ≥ 5 条建议（少于 5 条说明 ARB 已经够好，不必硬凑）
- [ ] 每条都同时给出原文 + 建议 + 理由
- [ ] 不破坏 ARB JSON 结构（CI 的 i18n coverage hook 会守门）
- [ ] CI 全绿

### Hints
- ARB 文件是 JSON-with-metadata 格式，改动只动 value 部分，不动 `@keyname` 元数据
- 参考已有 key 的语气（产品 UI 简洁、避免长定语）

---

## #4: `scripts/hooks/check-i18n-coverage.sh` — report unused keys

**Labels:** good first issue, dx
**Estimated effort:** 1-2 h
**Files:** `scripts/hooks/check-i18n-coverage.sh`
**Skill required:** Bash / grep basics

### Background
当前 i18n coverage hook 只检查 ARB 缺 key（en 有 / zh 没有 → 报错）。不检查反向：ARB 里定义了但代码里没用的"死 key"。日积月累 ARB 越来越臃肿。

### What to do
1. 增强 `scripts/hooks/check-i18n-coverage.sh`：扫一遍 `lib/**/*.dart`，对每个 `app_en.arb` 里的 key，检查是否在代码里被引用过
2. 找到的 unused key 用 warning 输出（**不阻塞 CI**，只报告）
3. 输出格式：`[i18n-unused] key_name (no references in lib/)`
4. README "Development" 段加一段说明这个 warning 怎么处理

### Acceptance criteria
- [ ] 脚本能跑出 unused key 列表（至少能正确识别一个明显的 unused key 用作 smoke test）
- [ ] 不破坏现有 missing-key 检查
- [ ] CI 全绿
- [ ] 跑一次本地，附 warning 输出截图到 PR

### Hints
- 引用模式：`context.l10n.<key>` / `AppLocalizations.of(context).<key>` / `S.current.<key>` 等
- 用 `grep -E` 比 awk 简单
- 注意 generated `lib/l10n/generated/` 不要扫（那里全是 key）

---

## #5: CONTRIBUTING.md — add "Setting up dev env on Windows" subsection

**Labels:** good first issue, docs, platform-windows
**Estimated effort:** 1 h
**Files:** `CONTRIBUTING.md`, possibly `docs/SETUP.md`
**Skill required:** Windows + Flutter Desktop setup experience

### Background
CONTRIBUTING.md 当前隐含假设维护者跑 macOS。Windows 贡献者首次 setup 的痛点（PostgreSQL 17 安装路径 / Visual Studio Build Tools / Flutter Windows desktop enablement）没有文档。

### What to do
1. 在 CONTRIBUTING.md 加一个 `## 开发环境 — Windows / Dev env on Windows` 子节
2. 列出最小可跑步骤：Flutter SDK / Visual Studio Build Tools 2022 / PostgreSQL 17 安装与服务启动 / `flutter config --enable-windows-desktop`
3. 涵盖最容易踩的坑（如 PG 服务没自动起）
4. 双语 OR 至少英文 + 中文目录同步

### Acceptance criteria
- [ ] CONTRIBUTING.md Windows 段 ≥ 30 行 ≤ 80 行
- [ ] 至少一个 PR 提交者照着跑能成功（自我验证 + PR description 里说明你跑过一次）
- [ ] 所有 link 检查无 404
- [ ] CI 全绿

### Hints
- 不需要写得像官方文档那么完整，"我踩过的坑 + 怎么解决"足够
- 维护者会在 review 时合并到现有 docs/SETUP.md（如果有）

---

## 创建命令参考（public 之后用）

```bash
gh label create "good first issue" --color "7057ff" --description "Good for newcomers" 2>/dev/null || true
gh label create "help wanted" --color "008672" --description "Extra attention is needed" 2>/dev/null || true
gh label create "chore" --color "ededed" 2>/dev/null || true
gh label create "docs" --color "0075ca" 2>/dev/null || true
gh label create "i18n" --color "fbca04" 2>/dev/null || true
gh label create "dx" --color "c2e0c6" 2>/dev/null || true
gh label create "platform-windows" --color "d4c5f9" 2>/dev/null || true

# 然后 5 条逐条 gh issue create --title ... --body ... --label "good first issue" --label "<area>"
```
