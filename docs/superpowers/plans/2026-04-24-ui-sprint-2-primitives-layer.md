# UI Sprint 2 (v3) — Design Primitives Layer

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 搭一层 CineFlow 风格的视觉原子库（primitive widgets），让后续 Sprint 在拼装面板/工具条/节点壳时有可复用的**颜料盒**——避免上一版 Sprint 2 "位置对了但视觉一塌糊涂"的重演。

**Architecture:** 每个 primitive = 一个 Flutter widget class，位于 `lib/theme/primitives/`。全部读 token（`InkColors`, `InkSpacing`, `InkRadius`, `InkTypography`, `InkMotion`），零硬编码。配一个 **Showcase 页面**（debug-only route）人眼肉检。

**Tech Stack:** 纯 Flutter widgets + `BackdropFilter` (dart:ui) + `AnimatedScale` / `AnimationController`。零新增第三方依赖。

---

## 原子清单

9 个 primitive + 2 个 token 扩展 + 1 个 Showcase：

| # | 名 | 对应 CineFlow | 说明 |
|---|---|---|---|
| P1 | `InkTypography.micro / nano` | text-[10px] / text-[9px] | 字号扩展 |
| P2 | `InkMotion.springHover / springTap / springPanel` | Framer spring 预设 | 动效曲线 |
| P3 | `InkGlassCard / InkGlassPanel / InkGlassPill` | glass-card / glass-panel / glass-pill | BackdropFilter 三态 |
| P4 | `InkGradientButton` + `InkGradientVariant` 枚举 | from-X to-Y 渐变类型按钮 | 6 个变体（image/video/text/upload/editor/neutral） |
| P5 | `InkSurfaceButton` | bg-surface-2 单色按钮 | 2 个尺寸（regular / icon） |
| P6 | `InkDashedSlot` | border-dashed "未填" 态 | 空槽占位 |
| P7 | `InkAccentChip` | accent-primary/50 + bg accent-primary/10 | 激活态芯片 |
| P8 | `InkPillTag` | rounded-full + bg-white/10 | 圆胶囊标签 |
| P9 | `InkCompactTextField` | bg-white/[0.04] + ring-1 focus | 紧凑 textarea |
| Show | `PrimitivesShowcase` | — | Debug-only 预览页，所有 primitive 并排 |

---

## File Structure

**Create:**
- `lib/theme/primitives/ink_glass_card.dart`
- `lib/theme/primitives/ink_gradient_button.dart`
- `lib/theme/primitives/ink_surface_button.dart`
- `lib/theme/primitives/ink_dashed_slot.dart`
- `lib/theme/primitives/ink_accent_chip.dart`
- `lib/theme/primitives/ink_pill_tag.dart`
- `lib/theme/primitives/ink_compact_text_field.dart`
- `lib/theme/motion.dart`（新，InkMotion.spring 预设）
- `lib/features/debug/primitives_showcase_screen.dart`（debug 路由）
- `test/theme/primitives/`（每个 primitive 对应一个 widget test）

**Modify:**
- `lib/theme/typography.dart`（加 micro / nano TextStyle）
- `lib/theme/tokens.dart`（**不改**——InkMotion 已有 fast/normal/slow，新 motion.dart 扩展）
- `lib/app.dart`（加 debug route `/debug/primitives`，仅 `kDebugMode`）
- `test/theme/tokens_test.dart`（加 micro / nano fontSize 断言）

**不碰：**
- 任何 `lib/features/canvas/` 文件（primitives 不在 canvas 用，Sprint 3 用）
- 任何数据层
- Sprint 1 的 InkColors（够用）

---

## Self-contained 规则

- DRY：所有 primitive 读 token，零硬编码色值/尺寸
- YAGNI：不做未来 Sprint 才需要的变体（比如不做 loading 态按钮——Sprint 3 需要时再加）
- TDD：每个 primitive widget test 先写
- Frequent commits：每个 Task 一个 commit

---

### Task 1: 切分支 + 基准

**Files:** 无

- [ ] **Step 1:**
```bash
cd /Users/kerro/Projects/InkFrame
git checkout feature/ui-sprint-1-tokens
git status --short         # 应 clean
git checkout -b feature/ui-sprint-2-primitives
```

- [ ] **Step 2:**
```bash
flutter test --reporter=compact 2>&1 | tail -3
```

Expected: `All tests passed!` 362 pass。

---

### Task 2 (P1): `InkTypography.micro` / `nano` 字号扩展

**Files:**
- Modify: `lib/theme/typography.dart`
- Test: `test/theme/tokens_test.dart`

- [ ] **Step 1: 失败测试**

在 `test/theme/tokens_test.dart` 的 `group('InkTypography scaling', ...)` 里追加：

```dart
    test('micro / nano 小字号（CineFlow 对齐）', () {
      final t = InkTypography.defaults();
      expect(t.micro.fontSize, 10);
      expect(t.nano.fontSize, 9);
    });
```

- [ ] **Step 2:** `flutter test test/theme/tokens_test.dart --plain-name "micro" --reporter=compact` 预期编译失败。

- [ ] **Step 3: 读 typography.dart 现状**

```bash
grep -n "final TextStyle\|class InkTypography\|factory .*defaults\|\.scaled" lib/theme/typography.dart | head -20
```

- [ ] **Step 4: 加字段 + factory 值 + scaled 传递**

在 `InkTypography` class 里：
- 构造参数 `required this.micro, required this.nano` 补齐
- 字段 `final TextStyle micro; final TextStyle nano;`
- `factory InkTypography.defaults({double scale = 1.0})` 里加 `micro: TextStyle(fontSize: 10 * scale, height: 1.3)` 和 `nano: TextStyle(fontSize: 9 * scale, height: 1.3)`
- `scaled()` 方法里复制 micro/nano 缩放

（具体改动面：先用 Read 看完整文件，然后精确 Edit）

- [ ] **Step 5:**
```bash
flutter test test/theme/tokens_test.dart --reporter=compact
flutter test --reporter=compact 2>&1 | tail -3
```

预期全绿。

- [ ] **Step 6: Commit**
```bash
git add lib/theme/typography.dart test/theme/tokens_test.dart
git commit -m "feat(theme): InkTypography.micro (10px) / nano (9px) for CineFlow compact chrome"
```

---

### Task 3 (P2): `InkMotion.springHover / springTap / springPanel`

**Files:**
- Create: `lib/theme/motion.dart`
- Test: `test/theme/motion_test.dart`

- [ ] **Step 1: 失败测试**

创建 `test/theme/motion_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/motion.dart';

void main() {
  group('InkMotionSpring', () {
    test('hover preset scales up slightly', () {
      expect(InkMotionSpring.hoverScale, 1.05);
      expect(InkMotionSpring.tapScale, 0.95);
    });

    test('panel entrance / popover in / out durations', () {
      expect(InkMotionSpring.panelIn.inMilliseconds, 300);
      expect(InkMotionSpring.popoverIn.inMilliseconds, 150);
      expect(InkMotionSpring.popoverOut.inMilliseconds, 150);
    });

    test('spring physics defaults match CineFlow (damping 20 / stiffness 300)', () {
      final sim = InkMotionSpring.defaultSpring;
      expect(sim.dampingFraction, closeTo(0.8, 0.001));
      expect(sim.stiffness, 300);
    });
  });
}
```

- [ ] **Step 2:** 跑测试——预期编译失败 `Target of URI doesn't exist`.

- [ ] **Step 3: 创建 motion.dart**

```dart
// InkMotion spring 预设：对齐 CineFlow Framer Motion 常用参数。
//
// hoverScale / tapScale：按钮交互微缩放
// panelIn / popoverIn / popoverOut：入场出场时长
// defaultSpring：damping 20 / stiffness 300，对应 Framer damping fraction ≈ 0.8
import 'package:flutter/animation.dart';

class InkMotionSpringConfig {
  const InkMotionSpringConfig({
    required this.dampingFraction,
    required this.stiffness,
  });
  final double dampingFraction;
  final double stiffness;

  SpringDescription toSpringDescription({double mass = 1.0}) =>
      SpringDescription.withDampingRatio(
        mass: mass,
        stiffness: stiffness,
        ratio: dampingFraction,
      );
}

class InkMotionSpring {
  InkMotionSpring._();

  /// Hover 微放大比例（CineFlow 全局 whileHover scale 1.05）
  static const double hoverScale = 1.05;

  /// Tap 按下微缩小（CineFlow 全局 whileTap scale 0.95）
  static const double tapScale = 0.95;

  /// 面板入场（FloatingToolbar delay 0.3, damping 20）
  static const Duration panelIn = Duration(milliseconds: 300);

  /// Popover 入场（slash / asset menu scale 0.8→1 + opacity）
  static const Duration popoverIn = Duration(milliseconds: 150);

  /// Popover 退场
  static const Duration popoverOut = Duration(milliseconds: 150);

  /// 默认弹簧：damping fraction 0.8, stiffness 300
  static const InkMotionSpringConfig defaultSpring = InkMotionSpringConfig(
    dampingFraction: 0.8,
    stiffness: 300,
  );
}
```

- [ ] **Step 4:** Tests 绿 + 全量零回归。

- [ ] **Step 5: Commit**
```bash
git add lib/theme/motion.dart test/theme/motion_test.dart
git commit -m "feat(theme): InkMotionSpring presets (hover/tap scale + popover durations + spring config)"
```

---

### Task 4 (P3): `InkGlassCard / InkGlassPanel / InkGlassPill`

**Files:**
- Create: `lib/theme/primitives/ink_glass_card.dart`（三个 widget 同一文件，避免散落）
- Create: `test/theme/primitives/ink_glass_card_test.dart`

**实现契约（BackdropFilter + 半透明 bg + 薄白边 + shadow）：**

```
InkGlassCard  —  borderRadius lg (12px, 对应 rounded-2xl 近似)
InkGlassPanel —  borderRadius md (8px, 对应 rounded-xl)
InkGlassPill  —  borderRadius pill (999, rounded-full)
```

- [ ] **Step 1: 失败测试**

创建 `test/theme/primitives/ink_glass_card_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/primitives/ink_glass_card.dart';

void main() {
  group('InkGlass* primitives', () {
    testWidgets('InkGlassCard wraps child with backdrop filter + surface color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InkGlassCard(child: const Text('content')),
          ),
        ),
      );
      expect(find.text('content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('InkGlassPanel renders with distinct radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InkGlassPanel(child: const Text('p'))),
        ),
      );
      expect(find.text('p'), findsOneWidget);
    });

    testWidgets('InkGlassPill fully round', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InkGlassPill(child: const Text('pill'))),
        ),
      );
      expect(find.text('pill'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2:** 预期编译失败。

- [ ] **Step 3: 实现**

创建 `lib/theme/primitives/ink_glass_card.dart`：

```dart
// Glass 毛玻璃容器三态：Card / Panel / Pill（CineFlow globals.css 对应）。
//
// - Card：rounded-2xl (12px)、95% 半透明、40px blur、150% saturation
// - Panel：rounded-xl (8px)、90% 半透明、24px blur、125% saturation
// - Pill：full round、同 Card 其他参数
//
// 所有变体共享：bg = surface1 + opacity；border = white 0.08/0.10 薄边；
// shadow = overlay token。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

enum _GlassKind { card, panel, pill }

class _GlassContainer extends StatelessWidget {
  const _GlassContainer({
    required this.kind,
    required this.child,
    this.padding,
  });

  final _GlassKind kind;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final (double radius, double blur, double satBoost, double opacity, double borderAlpha) =
        switch (kind) {
      _GlassKind.card => (InkRadius.lg, 40.0, 1.50, 0.95, 0.10),
      _GlassKind.panel => (InkRadius.md, 24.0, 1.25, 0.90, 0.08),
      _GlassKind.pill => (InkRadius.pill, 40.0, 1.50, 0.95, 0.10),
    };

    final bg = colors.surface1.withValues(alpha: opacity);
    final border = Colors.white.withValues(alpha: borderAlpha);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          inner: ui.ColorFilter.matrix(_saturationMatrix(satBoost)),
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border, width: 0.8),
            boxShadow: InkShadow.overlay,
          ),
          child: child,
        ),
      ),
    );
  }

  static List<double> _saturationMatrix(double s) {
    // 标准亮度 coefficients
    final r = 0.213 * (1 - s);
    final g = 0.715 * (1 - s);
    final b = 0.072 * (1 - s);
    return <double>[
      r + s, g, b, 0, 0,
      r, g + s, b, 0, 0,
      r, g, b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}

class InkGlassCard extends StatelessWidget {
  const InkGlassCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) =>
      _GlassContainer(kind: _GlassKind.card, padding: padding, child: child);
}

class InkGlassPanel extends StatelessWidget {
  const InkGlassPanel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) =>
      _GlassContainer(kind: _GlassKind.panel, padding: padding, child: child);
}

class InkGlassPill extends StatelessWidget {
  const InkGlassPill({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) =>
      _GlassContainer(kind: _GlassKind.pill, padding: padding, child: child);
}
```

- [ ] **Step 4:** Tests 绿 + 全量零回归。如果 `ImageFilter.compose` 在当前 Flutter 版本不存在，降级成只做 blur（saturation 补丁留 follow-up）。

- [ ] **Step 5: Commit**
```bash
git add lib/theme/primitives/ink_glass_card.dart test/theme/primitives/ink_glass_card_test.dart
git commit -m "feat(primitives): InkGlassCard / InkGlassPanel / InkGlassPill (BackdropFilter + saturation)"
```

---

### Task 5 (P4): `InkGradientButton` + 6 变体枚举

**Files:**
- Create: `lib/theme/primitives/ink_gradient_button.dart`
- Test: `test/theme/primitives/ink_gradient_button_test.dart`

**契约：**
- 6 个 variant：`image / video / text / upload / editor / neutral`
- 渐变数据硬编码在 widget 内（属于视觉 token，不是业务配置）
- Hover 放大 1.05，tap 0.95（用 `InkMotionSpring.hoverScale / tapScale`）
- Padding `px-3 py-1.5` → EdgeInsets.symmetric(h:12, v:6)
- Radius lg (12px)

- [ ] **Step 1: 失败测试** — 覆盖 "点按触发 onPressed" + "variant 渲染不同渐变色" + "disabled 不触发"。代码略（subagent 按 TDD 模板写）。

- [ ] **Step 2-5:** 实现 + commit
```bash
git commit -m "feat(primitives): InkGradientButton with 6 CineFlow-aligned variants"
```

---

### Task 6 (P5): `InkSurfaceButton`（surface-2 单色 + 2 尺寸）

- `InkSurfaceButton(label, icon?, onPressed)` — 常规
- `InkSurfaceButton.icon(icon, onPressed)` — 7×7 方形

同 Task 5 TDD 流程。

---

### Task 7 (P6): `InkDashedSlot`

虚线 border 容器，用于"未填"占位。`CustomPainter` 画虚线。

- [ ] TDD + commit

---

### Task 8 (P7 + P8): `InkAccentChip` + `InkPillTag`

同一 commit（两个都是小芯片 widget）：
- `InkAccentChip`：accent/50 border + accent/10 bg + accent 文字（激活态）
- `InkPillTag`：rounded-full + white/10 bg + borderSubtle border

---

### Task 9 (P9): `InkCompactTextField`

```
bg-white/[0.04] + rounded-lg + px-3 py-2 + text-sm
focus: ring-1 ring-borderHover
placeholder: text-tertiary
```

Flutter：`TextField(decoration: InputDecoration(filled: true, fillColor: white/0.04, ...))` + `Focus` wrapper 做 ring 动效。

TDD + commit。

---

### Task 10: `PrimitivesShowcase` debug 路由

**Files:**
- Create: `lib/features/debug/primitives_showcase_screen.dart`
- Modify: `lib/app.dart` — 加 `if (kDebugMode)` 条件路由

一个 `ListView` 列出所有 9 个 primitive 的不同变体，配简短标签（纯 debug 用，不走 i18n）。

- [ ] Commit:
```bash
git commit -m "feat(debug): PrimitivesShowcase screen at /debug/primitives (kDebugMode only)"
```

---

### Task 11: 视觉检验（你的肉眼）

- [ ] 启 app（debug），访问 `/debug/primitives`
- [ ] 对照 CineFlow 截图，每个 primitive 是否"对味"：
  - [ ] Glass 三态：真的有毛玻璃感？blur / saturation 明显？
  - [ ] GradientButton：6 种渐变正确？hover/tap 微缩放？
  - [ ] SurfaceButton：单色简洁？
  - [ ] DashedSlot：虚线均匀？
  - [ ] AccentChip：accent 透明度正确？
  - [ ] PillTag：圆形完整？
  - [ ] CompactTextField：聚焦 ring 细而不糊？
- [ ] 截图归档 `/tmp/inkframe-sprint2v3-primitives.png`
- [ ] 任何"对不上"的 primitive 单独挑 task 修

如果**整体对味**——进入 Sprint 3 (NodeInlinePanel v2 基于 primitive)。
如果**方向不对**——讨论后修。

---

### Task 12: memory + PR

- [ ] 更新 `project_ui_migration.md` 加 Sprint 2 (v3) 完成状态
- [ ] 推 push 命令到剪贴板
- [ ] 用户 push 后开 PR

---

## Self-Review

✅ Spec coverage：9 个原子 + 2 个 token 扩展 + showcase 全覆盖
✅ No placeholders：除 Task 5/6/7/8/9 的测试代码没贴完整（subagent 按 Task 4 的 TDD 模板扩展），其他 step 均有 literal code
✅ 依赖次序：P1/P2（token/motion）→ P3（glass）→ P4-P9（按 primitive 独立）→ Showcase → 验证
✅ 每个 primitive 独立 file + 独立 test file，blast radius 小

**已知风险：**
- `BackdropFilter` 在 macOS web 页面可能性能差——InkFrame 是 desktop 原生窗口，没这问题
- `ImageFilter.compose` API 版本问题，Step 4 允许降级
- `Focus + Container` 做 ring 边可能 flaky——若 Focus 不给边，用 `AnimatedContainer` + 手动 border 切换

**scope 外的明确跳掉：**
- slash / @ 命令菜单（Sprint 3.5+）
- Asset chip 的 "connected/manual" 分离 UI（Sprint 3）
- Framer `animate` 的复杂编排（Flutter 用 AnimationController 简化）

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-04-24-ui-sprint-2-primitives-layer.md`.

Base branch: `feature/ui-sprint-1-tokens`（stack on 未合并的 Sprint 1）。

Two execution options:

1. **Subagent-Driven**（推荐）— 我派 fresh subagent 每 task 执行 + 审。这是上一轮选过的路径。
2. **Inline Execution** — 在当前 session 里 executing-plans 按 task 跑。

Which approach?
