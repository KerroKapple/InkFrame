# UI Sprint 1 — CineFlow Token Migration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 CineFlow（`/Users/kerro/Projects/CineFlow`）的 CSS token 语义分层 1:1 移植成 InkFrame 的 Dart 设计令牌；运行时视觉色调与 CineFlow Dark 模式对齐（画布底色、面板、灰阶、Apple Blue accent、柔性语义色）。

**Architecture:** 扩展 `lib/theme/tokens.dart` 的 `InkColors` class，新增 CineFlow 用到但 InkFrame 缺的语义 slot（surface 0/4、border 4 级、text 4 级、accent hover/pressed、CTA、info）。同时把现有 slot 的 hex 值更新成 CineFlow 深色模式同色。老 widget 不改（仍读 `context.inkColors.surface1`），自动获得新视觉。`BorderRadius` 加 `bento / bentoBtn`。Typography / 字体 / 动画 / 组件结构 不在本 Sprint 范围，留后续 Sprint。

**Tech Stack:** Flutter / Dart / `flutter_test`。所有 token 都在 `lib/theme/` 一个文件夹，改动面极小，老 widget 零变动；新组件在后续 Sprint 里落地。

---

## 源 → 目标 Token 映射表

CineFlow 深色（`src/app/globals.css` `.dark`）→ InkFrame `InkColors.dark()`：

| CineFlow CSS var | HSL | Hex | InkFrame slot | 备注 |
|---|---|---|---|---|
| `--surface-0` | 228 10% 7% | `#101218` | `surfaceCanvas` (新) | 画布底 |
| `--surface-1` | 228 8% 12% | `#1B1D24` | `surface1` (改值) | 主面板 |
| `--surface-2` | 228 6% 16% | `#262830` | `surface2` (改值) | 卡片 |
| `--surface-3` | 228 5% 21% | `#323440` | `surface3` (改值) | 悬停 |
| `--surface-4` | 228 4% 26% | `#3E404C` | `surface4` (新) | 活跃控件 |
| `--border-subtle` | 228 6% 16% | `#262830` | `borderSubtle` (新) | |
| `--border-default` | 228 5% 22% | `#34363F` | `border` (改值) | 原 border 对应 |
| `--border-hover` | 228 4% 30% | `#484A54` | `borderHover` (新) | |
| `--border-focus` | 212 100% 50% | `#0080FF` | `focusRing` (改值) | Apple Blue |
| `--text-primary` | 0 0% 100% | `#FFFFFF` | `fg1` (改值) | |
| `--text-secondary` | 0 0% 81% | `#CFCECE` | `fg2` (改值) | |
| `--text-tertiary` | 0 0% 42% | `#6B6B6B` | `fg3` (改值) | |
| `--text-quaternary` | 0 0% 30% | `#4D4D4D` | `fg4` (新) | |
| `--accent` | 212 100% 50% | `#0080FF` | `accent` (改值) | Apple Blue |
| `--accent-hover` | 212 100% 44% | `#0070E0` | `accentHover` (新) | |
| `--accent-pressed` | 212 100% 38% | `#0060C0` | `accentPressed` (新) | |
| `--success` | 142 55% 45% | `#2EBD6B` | `success` (改值) | |
| `--warning` | 38 92% 50% | `#F59E0B` | `warning` (改值) | |
| `--error` | 0 72% 51% | `#E53E3E` | `danger` (改值) | |
| `--info` | 200 100% 45% | `#00A3D9` | `info` (新) | |
| `--cta` | 347 65% 48% | `#D42B57` | `cta` (新) | 品牌红 |
| `--cta-hover` | 347 65% 42% | `#BA2149` | `ctaHover` (新) | |

CineFlow 浅色 → `InkColors.light()` 同理（浅色 surface: `#FAFAFA / #FFFFFF / #F7F7F7 / #F2F2F2 / #EBEBEB`，text: `#1A1A1A / #737373 / #9E9E9E / #BFBFBF`，accent 保持 `#0080FF`）。

`InkColors.highContrast()` 保持 A11y 基线（纯黑白），仅给新 slot 补强对比值。

CineFlow 的 `bento-*` 是落地页独立子系统，InkFrame 不需要 → **不移植**。

CineFlow `sidebar-*` 是它独有侧栏组件，InkFrame 后续有对应组件再补 → **本 Sprint 不移植**。

Font (`Plus Jakarta Sans`)、Animation (`shimmer / pulse-subtle`) → **本 Sprint 不移植**（Sprint 2+）。

---

## File Structure

**Create:**
- `docs/superpowers/plans/2026-04-24-ui-sprint-1-token-migration.md`（本文档）

**Modify:**
- `lib/theme/tokens.dart` — `InkColors` 新增 9 个 slot + 3 个工厂改值；`InkRadius` 加 `bento` / `bentoBtn`。
- `lib/theme/app_theme.dart` — `ColorScheme.primary` 切换 `colors.brand` → `colors.accent`（Apple Blue 打主色）；其余保持。
- `test/theme/tokens_test.dart` — 新增断言：新 slot 存在 + 核心 hex 等于 CineFlow 对应值 + ColorScheme.primary == InkColors.accent。

**不碰（显式声明）:**
- `lib/theme/typography.dart`（字体下个 Sprint）
- 任何 widget 文件（视觉自动通过改 hex 传导）

---

## Self-contained 规则校验

**DRY:** InkColors 新 slot 统一挂单一 class，不建副本类。
**YAGNI:** 不加 sidebar / bento / font / animation（CineFlow 有但本 Sprint 用不到）。
**TDD:** 每个改动先写失败测试，再实现。
**Frequent commits:** 每个 Task 一个 commit。

---

### Task 1: 准备新分支 + 开始跑基准测试

**Files:** 无文件改动

- [ ] **Step 1: 切新分支**

```bash
git fetch origin dev --quiet
git checkout -b feature/ui-sprint-1-tokens origin/dev
```

- [ ] **Step 2: 跑基准 test 验证起点绿**

```bash
flutter test test/theme/tokens_test.dart --reporter=compact
```

Expected: `All tests passed!`（17 个测试全过）

---

### Task 2: 新增 9 个语义 slot 字段声明（失败测试 + 实现）

**Files:**
- Modify: `lib/theme/tokens.dart`
- Test: `test/theme/tokens_test.dart`

- [ ] **Step 1: 先在 tokens_test.dart 写失败测试（TDD）**

在 `test/theme/tokens_test.dart` 的 `group('InkColors variants', ...)` 内，在 `test('every variant exposes all 15 semantic slots', ...)` 之后追加：

```dart
    test('every variant exposes the 9 new CineFlow-aligned slots', () {
      for (final InkColors c in <InkColors>[
        InkColors.dark(),
        InkColors.light(),
        InkColors.highContrast(),
      ]) {
        expect(c.surfaceCanvas, isA<Color>());
        expect(c.surface4, isA<Color>());
        expect(c.borderSubtle, isA<Color>());
        expect(c.borderHover, isA<Color>());
        expect(c.fg4, isA<Color>());
        expect(c.accentHover, isA<Color>());
        expect(c.accentPressed, isA<Color>());
        expect(c.info, isA<Color>());
        expect(c.cta, isA<Color>());
        expect(c.ctaHover, isA<Color>());
      }
    });
```

注意 count 从 15 更新到 25 的 group 校验在后续 Task 做，本 step 只加新 slot 校验。

- [ ] **Step 2: 跑测试验证失败**

```bash
flutter test test/theme/tokens_test.dart --plain-name "9 new CineFlow-aligned slots" --reporter=compact
```

Expected: 编译失败，错误类似 `The getter 'surfaceCanvas' isn't defined for the class 'InkColors'`。

- [ ] **Step 3: 在 InkColors class 加字段声明 + 构造参数**

编辑 `lib/theme/tokens.dart`，将 `const InkColors._({...})` 扩展：

```dart
  const InkColors._({
    required this.surfaceCanvas,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.surface4,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.fg4,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.brand,
    required this.cta,
    required this.ctaHover,
    required this.danger,
    required this.warning,
    required this.success,
    required this.info,
    required this.border,
    required this.borderSubtle,
    required this.borderHover,
    required this.focusRing,
    required this.overlay,
    required this.scrim,
  });
```

同时在底部加字段：

```dart
  final Color surfaceCanvas; // 画布最底层（surface-0）
  final Color surface4; // 活跃控件
  final Color fg4; // 极弱辅助文本
  final Color accentHover;
  final Color accentPressed;
  final Color cta; // 品牌红（主行动呼唤）
  final Color ctaHover;
  final Color info; // 语义信息
  final Color borderSubtle;
  final Color borderHover;
```

放在已有字段附近（`surface3` 后加 `surface4`，`fg3` 后加 `fg4`，`accent` 后加 `accentHover / accentPressed`，`brand` 后加 `cta / ctaHover`，`success` 后加 `info`，`border` 后加 `borderSubtle / borderHover`）。

**编译器会立刻报 dark / light / highContrast 三个工厂方法缺参数——这是预期的，下一个 Task 会修。**

- [ ] **Step 4: 更新 dark() 工厂，填 CineFlow Dark 对应值**

在 `factory InkColors.dark()` 的参数列表里加：

```dart
  factory InkColors.dark() => const InkColors._(
        surfaceCanvas: Color(0xFF101218),
        surface1: Color(0xFF1B1D24),
        surface2: Color(0xFF262830),
        surface3: Color(0xFF323440),
        surface4: Color(0xFF3E404C),
        fg1: Color(0xFFFFFFFF),
        fg2: Color(0xFFCFCECE),
        fg3: Color(0xFF6B6B6B),
        fg4: Color(0xFF4D4D4D),
        accent: Color(0xFF0080FF),
        accentHover: Color(0xFF0070E0),
        accentPressed: Color(0xFF0060C0),
        brand: Color(0xFFA88BFF), // 保留紫（InkFrame 品牌，非 CineFlow 范畴）
        cta: Color(0xFFD42B57),
        ctaHover: Color(0xFFBA2149),
        danger: Color(0xFFE53E3E),
        warning: Color(0xFFF59E0B),
        success: Color(0xFF2EBD6B),
        info: Color(0xFF00A3D9),
        border: Color(0xFF34363F),
        borderSubtle: Color(0xFF262830),
        borderHover: Color(0xFF484A54),
        focusRing: Color(0xFF0080FF),
        overlay: Color(0xCC101218),
        scrim: Color(0x99000000),
      );
```

注意：`brand` 不改（保留 InkFrame 紫色品牌），其余色完全按 CineFlow 深色模式。

- [ ] **Step 5: 更新 light() 工厂**

```dart
  factory InkColors.light() => const InkColors._(
        surfaceCanvas: Color(0xFFFAFAFA),
        surface1: Color(0xFFFFFFFF),
        surface2: Color(0xFFF7F7F7),
        surface3: Color(0xFFF2F2F2),
        surface4: Color(0xFFEBEBEB),
        fg1: Color(0xFF1A1A1A),
        fg2: Color(0xFF737373),
        fg3: Color(0xFF9E9E9E),
        fg4: Color(0xFFBFBFBF),
        accent: Color(0xFF0080FF),
        accentHover: Color(0xFF0070E0),
        accentPressed: Color(0xFF0060C0),
        brand: Color(0xFF4A2FD1),
        cta: Color(0xFFD42B57),
        ctaHover: Color(0xFFBA2149),
        danger: Color(0xFFE53E3E),
        warning: Color(0xFFF59E0B),
        success: Color(0xFF2E8C57),
        info: Color(0xFF00A3D9),
        border: Color(0xFFE0E0E0),
        borderSubtle: Color(0xFFEBEBEB),
        borderHover: Color(0xFFCCCCCC),
        focusRing: Color(0xFF0080FF),
        overlay: Color(0xCCFAFAFA),
        scrim: Color(0x66000000),
      );
```

- [ ] **Step 6: 更新 highContrast() 工厂（保持纯黑白 A11y 基线 + 新 slot）**

```dart
  factory InkColors.highContrast() => const InkColors._(
        surfaceCanvas: Color(0xFF000000),
        surface1: Color(0xFF000000),
        surface2: Color(0xFF0A0A0A),
        surface3: Color(0xFF151515),
        surface4: Color(0xFF202020),
        fg1: Color(0xFFFFFFFF),
        fg2: Color(0xFFF0F0F0),
        fg3: Color(0xFFDADADA),
        fg4: Color(0xFFBEBEBE),
        accent: Color(0xFFFFD400),
        accentHover: Color(0xFFFFE550),
        accentPressed: Color(0xFFF5C000),
        brand: Color(0xFFFFD400),
        cta: Color(0xFFFFD400),
        ctaHover: Color(0xFFFFE550),
        danger: Color(0xFFFF6A6A),
        warning: Color(0xFFFFD400),
        success: Color(0xFF66FFB0),
        info: Color(0xFF66E0FF),
        border: Color(0xFFFFFFFF),
        borderSubtle: Color(0xFFA0A0A0),
        borderHover: Color(0xFFFFFFFF),
        focusRing: Color(0xFFFFD400),
        overlay: Color(0xEE000000),
        scrim: Color(0xCC000000),
      );
```

- [ ] **Step 7: 跑测试验证通过**

```bash
flutter test test/theme/tokens_test.dart --reporter=compact
```

Expected: `All tests passed!`（新加的 9 slot 测试 + 原有 17 个都过）。

- [ ] **Step 8: 跑全量 test 确保零回归**

```bash
flutter test --reporter=compact 2>&1 | tail -3
```

Expected: `349 pass / 0 fail / 30 skipped`

- [ ] **Step 9: Commit**

```bash
git add lib/theme/tokens.dart test/theme/tokens_test.dart
git commit -m "feat(theme): extend InkColors with 9 CineFlow-aligned slots + port palette values"
```

---

### Task 3: 更新现有 slot 值测试断言（dark 亮度 + highContrast fg1 等）

**背景:** Task 2 更新了 dark() 的 surface1 从 `#0F0F13` (亮度≈0.005) 到 `#1B1D24` (亮度≈0.011)——都远 < 0.1，现有测试 `expect(colors.surface1.computeLuminance(), lessThan(0.1))` 不会挂。highContrast fg1 = `#FFFFFF` 也不变。**本 Task 加断言验证 core hex**，不仅仅是亮度范围。

**Files:**
- Test: `test/theme/tokens_test.dart`

- [ ] **Step 1: 在 tokens_test.dart 追加精确 hex 断言（CineFlow 对齐验证）**

在 `group('InkColors variants', ...)` 内追加：

```dart
    test('dark variant exact values match CineFlow dark palette', () {
      final c = InkColors.dark();
      expect(c.surfaceCanvas, const Color(0xFF101218));
      expect(c.surface1, const Color(0xFF1B1D24));
      expect(c.surface2, const Color(0xFF262830));
      expect(c.surface3, const Color(0xFF323440));
      expect(c.surface4, const Color(0xFF3E404C));
      expect(c.accent, const Color(0xFF0080FF));
      expect(c.accentHover, const Color(0xFF0070E0));
      expect(c.accentPressed, const Color(0xFF0060C0));
      expect(c.cta, const Color(0xFFD42B57));
      expect(c.info, const Color(0xFF00A3D9));
      expect(c.fg1, const Color(0xFFFFFFFF));
      expect(c.fg2, const Color(0xFFCFCECE));
      expect(c.fg3, const Color(0xFF6B6B6B));
      expect(c.fg4, const Color(0xFF4D4D4D));
    });

    test('light variant exact values match CineFlow light palette', () {
      final c = InkColors.light();
      expect(c.surfaceCanvas, const Color(0xFFFAFAFA));
      expect(c.surface1, const Color(0xFFFFFFFF));
      expect(c.accent, const Color(0xFF0080FF)); // Apple Blue 两模共用
      expect(c.cta, const Color(0xFFD42B57));
      expect(c.fg1, const Color(0xFF1A1A1A));
    });
```

- [ ] **Step 2: 跑测试验证通过（Task 2 实现已满足，这里仅补强断言）**

```bash
flutter test test/theme/tokens_test.dart --reporter=compact
```

Expected: `All tests passed!`

- [ ] **Step 3: Commit**

```bash
git add test/theme/tokens_test.dart
git commit -m "test(theme): assert exact CineFlow palette hex values in InkColors.dark / light"
```

---

### Task 4: InkRadius 扩展 bento / bentoBtn（CineFlow 卡片常用圆角）

**Files:**
- Modify: `lib/theme/tokens.dart`
- Test: `test/theme/tokens_test.dart`

- [ ] **Step 1: 先写失败测试**

在 `group('InkSpacing / InkRadius', ...)` 内的 `test('radius tokens cover common UI needs', ...)` **之后** 追加：

```dart
    test('radius includes CineFlow bento tokens', () {
      expect(InkRadius.bento, 10);
      expect(InkRadius.bentoBtn, 6);
    });
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/theme/tokens_test.dart --plain-name "CineFlow bento tokens" --reporter=compact
```

Expected: 编译失败，`The getter 'bento' isn't defined for the class 'InkRadius'`。

- [ ] **Step 3: 在 `lib/theme/tokens.dart` 的 `class InkRadius` 内加两行静态常量**

```dart
class InkRadius {
  InkRadius._();
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 999;
  static const double bento = 10;    // CineFlow bento 卡片
  static const double bentoBtn = 6;  // CineFlow bento 按钮
}
```

- [ ] **Step 4: 跑测试验证通过**

```bash
flutter test test/theme/tokens_test.dart --reporter=compact
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/theme/tokens.dart test/theme/tokens_test.dart
git commit -m "feat(theme): add InkRadius.bento / bentoBtn (10/6) for CineFlow card radius"
```

---

### Task 5: 把 ColorScheme.primary 绑定从 brand (紫) 切到 accent (Apple Blue)

**背景:** 当前 `app_theme.dart:70` 用 `colors.brand` (紫 `#A88BFF`) 做 `ColorScheme.primary`。CineFlow 主色是 Apple Blue `#0080FF`。切绑定后所有 Material3 组件（Button / Switch / Slider / etc）默认主色直接变蓝，不需改 widget。

**Files:**
- Modify: `lib/theme/app_theme.dart`
- Test: `test/theme/tokens_test.dart`

- [ ] **Step 1: 先写失败测试**

在 `group('buildAppTheme', ...)` 内追加：

```dart
    testWidgets('ColorScheme.primary is Apple Blue (CineFlow accent)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(
            variant: InkThemeVariant.dark,
            textScale: 1,
          ),
          home: Builder(
            builder: (ctx) {
              final scheme = Theme.of(ctx).colorScheme;
              expect(scheme.primary, const Color(0xFF0080FF));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/theme/tokens_test.dart --plain-name "Apple Blue" --reporter=compact
```

Expected: 测试失败，实际值是 `0xFFA88BFF`（当前 brand 紫）。

- [ ] **Step 3: 修改 `lib/theme/app_theme.dart` 的 ColorScheme 绑定**

找到 `colorScheme: ColorScheme(...)` 块，把 `primary` 从 `colors.brand` 改成 `colors.accent`：

```dart
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: colors.accent,      // 原: colors.brand
      onPrimary: colors.fg1,
      secondary: colors.brand,     // 原: colors.accent，互换到 secondary 保留紫
      onSecondary: colors.fg1,
      error: colors.danger,
      onError: colors.fg1,
      surface: colors.surface2,
      onSurface: colors.fg1,
    ),
```

- [ ] **Step 4: 跑测试验证通过**

```bash
flutter test test/theme/tokens_test.dart --reporter=compact
```

Expected: `All tests passed!`

- [ ] **Step 5: 跑全量 test 确认零回归**

```bash
flutter test --reporter=compact 2>&1 | tail -3
```

Expected: `349 pass / 0 fail / 30 skipped`

- [ ] **Step 6: Commit**

```bash
git add lib/theme/app_theme.dart test/theme/tokens_test.dart
git commit -m "refactor(theme): swap ColorScheme primary to Apple Blue accent (CineFlow alignment)"
```

---

### Task 6: 视觉验证（跑 app，人眼看与 CineFlow 是否色调对齐）

**Files:** 无代码改动，纯观察 Task。

- [ ] **Step 1: 起 debug app（带 fake providers，不烧 key）**

```bash
pkill -9 -f "inkframe" 2>/dev/null ; pkill -9 -f "flutter run -d macos" 2>/dev/null ; sleep 2
INKFRAME_PG_BIN=/opt/homebrew/opt/postgresql@17/bin INKFRAME_FAKE_PROVIDERS=1 flutter run -d macos --debug
```

Expected: App 在 ~1-2 min 后窗口弹出。

- [ ] **Step 2: 并排打开 CineFlow（浏览器）对比**

在浏览器跑 CineFlow（本地或 Vercel 部署），同屏打开 InkFrame app。观察：
- 画布底色是否接近 CineFlow `surface-0` (#101218)
- 主面板是否接近 `surface-1` (#1B1D24)
- 文本白度是否接近 pure white
- accent button / focus ring 是否 Apple Blue

- [ ] **Step 3: 截屏归档（非阻塞性）**

```bash
screencapture -t png /tmp/inkframe-sprint1-before-components.png
```

说明：这张截图作为 Sprint 1 **token-only** 的完成态视觉基线，Sprint 2 component 迁移后再截一张对比看 component 改造增量效果。

- [ ] **Step 4: 关 app**

在 Terminal 跑 flutter run 的窗口按 `q` 退出。

- [ ] **Step 5: (可选) 如色调明显对不上，回退查漏**

本 Sprint 仅做 token，不应有组件层级漂移。如视觉仍像老版 InkFrame，排查顺序：
1. 确认 `InkColors.dark()` hex 已按 Task 2-3 更新（`grep -n 0x101218 lib/theme/tokens.dart`）
2. 确认 `buildAppTheme` 用的是 dark 变体（检查 ThemeModeController）
3. 强制 hot restart（`R` in flutter run terminal）

---

### Task 7: 更新 memory + README 注记 + PR

**Files:**
- Modify: `/Users/kerro/.claude/projects/-Users-kerro-Projects-InkFrame/memory/MEMORY.md`（加 UI 迁移条目）
- New: `/Users/kerro/.claude/projects/-Users-kerro-Projects-InkFrame/memory/project_ui_migration.md`

- [ ] **Step 1: 写 memory 记录 UI 迁移 Sprint 路线**

创建 `/Users/kerro/.claude/projects/-Users-kerro-Projects-InkFrame/memory/project_ui_migration.md`：

```markdown
---
name: InkFrame UI 迁移 CineFlow 方向 Sprint 路线
description: Sprint 1 token 已做，Sprint 2+ 待起
type: project
---
**起因**：T5 Sprint 收口后用户手动回归发现 InkFrame UI 不够 polished，指定"按 CineFlow (`/Users/kerro/Projects/CineFlow`) 的风格重做"。

**方法论：token-first**
- Sprint 1（2026-04-24）已做：token 层 1:1 移植 CineFlow 的 CSS 变量（surface 0-4 / border 4 级 / text 4 级 / accent 三态 / cta / info / bento radius），ColorScheme.primary 切到 Apple Blue。老 widget 零改动，视觉自动传导。
- Sprint 2+ 待做：组件结构级迁移——FloatingToolbar → NodeCreationMenu → StyledEdge → NodeInlinePanel → FlowCanvas。按 hero 组件优先顺序拆 Sprint。
- 字体（Plus Jakarta Sans）、动画（shimmer / pulse-subtle）留后续 Sprint。

**Why:** CineFlow 是用户自己的作品，设计语言他熟；1:1 移植比重新设计省决策成本。

**How to apply:**
- 下次用户提 "改 UI / 美化 / 改画布"，不要自己乱加色值——先看 CineFlow 对应处怎么做
- 新组件读 `context.inkColors.surfaceCanvas / surface4 / fg4 / accentHover / accentPressed / cta / ctaHover / info / borderSubtle / borderHover` 这些新 slot
- Bento 子系统（landing page 专用）在 CineFlow 里有，InkFrame 不需要，**不移植**
```

追加到 `MEMORY.md`（末尾加一行）：

```markdown
- [UI 迁移 CineFlow 方向](project_ui_migration.md) — token 已对齐 Apple Blue + 5 级 surface；组件 port 分多个 Sprint
```

- [ ] **Step 2: 推 push 命令到剪贴板（用户自己跑 pre-push）**

```bash
printf 'git push -u origin feature/ui-sprint-1-tokens' | pbcopy
echo "已复制：git push -u origin feature/ui-sprint-1-tokens"
```

- [ ] **Step 3: 用户粘贴执行 push 后，开 PR**

```bash
gh pr create --base dev --head feature/ui-sprint-1-tokens --title "feat(theme): UI Sprint 1 — CineFlow token migration (colors + radius)" --body "$(cat <<'EOF'
## Summary
UI 迁移 Sprint 1：把 CineFlow 的 CSS token 语义分层 1:1 移植到 InkFrame 的 Dart token 层。

### 色板
- InkColors 新增 9 slot：surfaceCanvas / surface4 / fg4 / accentHover / accentPressed / cta / ctaHover / info / borderSubtle / borderHover
- dark() hex 全量对齐 CineFlow Dark 模式（surface 228° hue 冷蓝灰，accent #0080FF Apple Blue）
- light() hex 全量对齐 CineFlow Light 模式（macOS 风格）
- highContrast() 保留 A11y 基线 + 新 slot 补强

### Radius
- InkRadius.bento = 10 / bentoBtn = 6（CineFlow 卡片圆角规格）

### ColorScheme
- primary 从 brand 紫切到 accent Apple Blue（Material3 组件默认主色）
- secondary 接住原紫（brand 仍是 InkFrame 品牌）

### Widget 改动
无。老 widget 读 `context.inkColors.surface1` 等老 slot，值自动变成 CineFlow hex。

## Scope 不含
- 字体（Plus Jakarta Sans 留 Sprint 2）
- 动画（shimmer / pulse-subtle 留 Sprint 2）
- 组件结构（FlowCanvas / NodeInlinePanel / FloatingToolbar 各自独立 Sprint）
- Bento 子系统（CineFlow landing page 专用，InkFrame 不需要）

## Test plan
- [x] tokens_test.dart 扩展：新 slot 存在 + dark/light exact hex 断言 + ColorScheme.primary == accent
- [x] flutter test 全量 349 pass / 0 fail
- [x] 人眼视觉验证：app 跑起来色调接近 CineFlow Dark
EOF
)"
```

---

## Self-Review

✅ Spec coverage（映射表里每一行 slot 在 Task 2 里都有赋值）
✅ No placeholders（所有代码段都是 literal Dart / bash，无 "TBD"）
✅ Type consistency（`surfaceCanvas` 在 Task 2 声明，在 Task 3 断言，同名一致；`InkRadius.bento` 在 Task 4 声明 + 断言同名）
✅ TDD（每个改动先失败测试再实现）
✅ 粒度（每 step 2-5 分钟动作）
✅ 绝对路径（所有 file 指代都是绝对或 repo 相对）

**遗漏风险评估：**
- 风险 1：Task 2 Step 3 改 `InkColors._` 构造参数时，编译器会要求 dark/light/highContrast 三个工厂都补参数——**Task 2 Step 4/5/6 正好是三个工厂的实现**，顺序对齐即可编译通过。
- 风险 2：现有 widget 使用 `context.inkColors.surface1` 当下值从 `0xFF0F0F13` 变 `0xFF1B1D24`，人眼视觉会变——这是**预期**效果，不算回归。
- 风险 3：`tokens_test.dart` 原 `'every variant exposes all 15 semantic slots'` 测试断言 15 个 slot——Task 2 新加 10 个字段但不 rename 旧字段，原测试继续通过。**不需要改** `every variant exposes all 15 semantic slots` 这个测试（保留向后兼容，Sprint 4+ 如统一命名规范再考虑）。
- 风险 4：浅色 / highContrast 与 CineFlow 对应色不一定像 Dark 那样完美——本 Sprint 不做精修，后续 A11y Sprint 统一过一遍。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-24-ui-sprint-1-token-migration.md`. Two execution options:

**1. Subagent-Driven (recommended)** - 我派一个 fresh subagent 一任务一任务执行，每个 Task 完成后我 review，然后下一个

**2. Inline Execution** - 我在本 session 里按 executing-plans 直接跑，每个 Task 跑完贴进度给你，你审后跑下一个

Which approach?
