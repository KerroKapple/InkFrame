# ON-3 无 ffmpeg 降级提示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 设置页 About 区仿「安全存储探测」模式加 ffmpeg 状态行：找到=路径（success 色）；未找到=平台化安装指引（warning 色——降级非故障）。

**Architecture:** `ffmpegProbeProvider`（autoDispose FutureProvider，包 `ffmpegLocatorProvider.locate()`）+ AboutSection 一行 `_Row`。文案与导出对话框 `exportVideoFfmpegMissing` 对齐防双源：mac/win 各自细分（brew/winget + INKFRAME_FFMPEG 兜底），其余平台直接复用该键。

**Tech Stack:** 既有 FfmpegLocator（miss 不缓存——autoDispose 重进设置页即重探,无需重启）、ARB gen-l10n。

## Global Constraints

- testWidgets 禁真 dart:io await（sync-IO 坑）：**所有** about_section 既有用例补 `ffmpegLocatorProvider` fake override，否则默认 locator 真 spawn `ffmpeg -version` 挂测试。
- ARB +5 键 en/zh 全覆盖 + gen-l10n 产物同 commit。
- 平台分支用 `defaultTargetPlatform`（测试经 `debugDefaultTargetPlatformOverride` 驱动）。

### Task 1: ffmpeg 状态行（TDD）

**Files:**
- Modify: `lib/features/settings/widgets/about_section.dart`
- Modify: `lib/l10n/app_en.arb` / `app_zh.arb`（+5 键：settingsAboutFfmpegLabel / Available{path} / Probing / MissingMac / MissingWindows）+ generated/
- Test: `test/features/settings/about_section_test.dart`

**Interfaces:**
- Produces: `ffmpegProbeProvider = FutureProvider.autoDispose<String?>`（null=未找到）。
- Consumes: `ffmpegLocatorProvider`（core/di/video_export.dart）。

- [ ] **Step 1 红测**：`_FakeFfmpegLocator(path)` 实现 FfmpegLocator；用例：①found→显示路径;②null+win（debugDefaultTargetPlatformOverride）→ 文案含 winget+INKFRAME_FFMPEG;③null+mac→含 brew;④null+其他平台→复用 exportVideoFfmpegMissing 文案。既有 7 用例全部补 fake override（默认给 found,避免真探测）。
- [ ] **Step 2**：ARB +5 键（en/zh）+ `flutter gen-l10n`。
- [ ] **Step 3 实现**：about_section 加 provider + `_Row`（value: data path→Available(path)/success;null→平台 switch missing 文案/warning;loading→Probing/fg2）。
- [ ] **Step 4 绿** + 全量闸门（analyze + 全套）。
- [ ] **Step 5 commit** — `feat(settings): ON-3 About 区 ffmpeg 状态行`

### Task 2: docs 登记 + PR

- [ ] BOARD 近期落地表 + MASTERPLAN 第 10 条 ON-3 打勾（同 PR）。
- [ ] PR → 对抗评审（关注:测试真探测泄漏、平台分支、双源文案）→ 修 P1/P2 → CI 一次性核验 → squash merge。

## Self-Review

- 范围=设置页探测行（#143 已把导出对话框文案收口,ON-3 剩余范围即此）✓
- 键名与 secure storage 行命名系一致 ✓；无占位符 ✓
