# UI Amber Noir Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cyberpunk-glass UI with the Amber Noir design (Lock + Studio Home + Canvas + frameless window) defined in `docs/superpowers/specs/2026-05-13-ui-redesign-design.md`.

**Architecture:** Token-first rewrite — colors already swapped in commit `3234aea`. Add bundled serif/mono fonts + new primitives (`InkNoirCard` / `InkAmberButton` / `InkGhostButton`). Build 3 new feature screens (Lock + Studio + reworked Canvas) on top. Frameless window via `window_manager` + custom chrome. Delete deprecated glass/gradient primitives last.

**Tech Stack:** Flutter Desktop (macOS+Windows), Riverpod, go_router (already present), `window_manager` (NEW), `flutter_localizations`, Cormorant Garamond + JetBrains Mono (NEW assets), `flutter_secure_storage`.

**Reference materials:**
- Spec: `docs/superpowers/specs/2026-05-13-ui-redesign-design.md`
- Mockups: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/index.html`
- Source images: `D:\Docs\IMG\IF\*.png`

---

## File Map

### New files

```
assets/fonts/
├── CormorantGaramond-Light.ttf
├── CormorantGaramond-Regular.ttf
├── CormorantGaramond-Medium.ttf
├── CormorantGaramond-Italic.ttf
├── JetBrainsMono-Regular.ttf
└── JetBrainsMono-Medium.ttf

lib/theme/primitives/
├── ink_noir_card.dart           # 替代 InkGlassCard
├── ink_amber_button.dart        # CTA 实色按钮
└── ink_ghost_button.dart        # 次按钮（hover 才有边）

lib/theme/components/
└── ink_window_chrome.dart       # 自绘标题栏 + 三按钮

lib/features/lock/
├── lock_screen.dart             # Lock UI
├── controllers/
│   └── lock_controller.dart     # API key submit + 验证
└── widgets/
    ├── lock_logo.dart           # 衬线 Ink/Frame logo
    └── lock_secure_field.dart   # 下划线密码输入框

lib/features/studio/
├── studio_home_screen.dart      # 重写后的工作台
├── controllers/
│   └── studio_state.dart        # selectedProjectId / currentStudio
└── widgets/
    ├── library_sidebar.dart     # 左侧目录树
    ├── project_card.dart        # 4 列网格的单卡
    └── studio_top_chrome.dart   # 顶部 breadcrumb + avatar

lib/features/canvas/
└── widgets/
    ├── canvas_node_card.dart    # 节点视觉重做
    ├── canvas_inspector.dart    # 右侧 Inspector
    ├── canvas_render_queue.dart # Inspector 下方队列面板
    ├── canvas_top_chrome.dart
    └── canvas_left_toolbar.dart
```

### Modified files

```
pubspec.yaml                                       # 加 window_manager + fonts assets
lib/main.dart                                      # windowManager.ensureInitialized + chrome wrapping
lib/app.dart                                       # 路由 redirect 接 apiKeyUnlockedProvider
lib/theme/typography.dart                          # 加 display/headline/caption + fontFamily
lib/core/di/secure_storage.dart                    # 新 apiKeyUnlockedProvider
lib/features/workspace/workspace_home_screen.dart  # 删除（被 studio 替代）
lib/l10n/app_en.arb + app_zh.arb                   # 新 i18n keys
test/theme/tokens_test.dart                        # 已对齐，无需改
test/features/lock/lock_screen_test.dart           # 新增
test/features/studio/studio_home_test.dart         # 新增
```

### Deleted files (Task 12)

```
lib/theme/primitives/ink_glass_card.dart
lib/theme/primitives/ink_gradient_button.dart
lib/theme/primitives/ink_pill_tag.dart
```

---

## Task 1 — Dependencies & Font Assets

**Files:**
- Modify: `pubspec.yaml`
- Create: `assets/fonts/CormorantGaramond-Light.ttf` 等 6 个字体
- Modify: `pubspec.yaml`（assets 段）

- [ ] **Step 1: 下载字体到 assets/fonts/**

```bash
mkdir -p assets/fonts
# Cormorant Garamond (OFL)
curl -L -o assets/fonts/CormorantGaramond-Light.ttf \
  https://fonts.gstatic.com/s/cormorantgaramond/v16/co3YmX5slCNuHLi8bLeY9MK7whWMhys.ttf
curl -L -o assets/fonts/CormorantGaramond-Regular.ttf \
  https://fonts.gstatic.com/s/cormorantgaramond/v16/co3bmX5slCNuHLi8bLeY9MK7whWMhys.ttf
curl -L -o assets/fonts/CormorantGaramond-Medium.ttf \
  https://fonts.gstatic.com/s/cormorantgaramond/v16/co3YmX5slCNuHLi8bLeY9MK7whWMhys.ttf
curl -L -o assets/fonts/CormorantGaramond-Italic.ttf \
  https://fonts.gstatic.com/s/cormorantgaramond/v16/co3WmX5slCNuHLi8bLeY9MK7whWMhys.ttf
# JetBrains Mono (Apache 2.0)
curl -L -o assets/fonts/JetBrainsMono-Regular.ttf \
  https://fonts.gstatic.com/s/jetbrainsmono/v18/tDbY2o-flEEny0FZhsfKu5WU4zr3E_BX.ttf
curl -L -o assets/fonts/JetBrainsMono-Medium.ttf \
  https://fonts.gstatic.com/s/jetbrainsmono/v18/tDbY2o-flEEny0FZhsfKu5WU4zr3E_BX.ttf
```

(若 fonts.gstatic.com URL 失效，从 https://fonts.google.com/specimen/Cormorant+Garamond 与 https://fonts.google.com/specimen/JetBrains+Mono 下载替代。)

- [ ] **Step 2: pubspec.yaml 加依赖**

打开 `pubspec.yaml`，在 `dependencies:` 段加：

```yaml
  window_manager: ^0.4.3
```

- [ ] **Step 3: pubspec.yaml 注册字体**

在 `flutter:` 段加：

```yaml
  assets:
    - assets/fonts/

  fonts:
    - family: CormorantGaramond
      fonts:
        - asset: assets/fonts/CormorantGaramond-Light.ttf
          weight: 300
        - asset: assets/fonts/CormorantGaramond-Regular.ttf
          weight: 400
        - asset: assets/fonts/CormorantGaramond-Medium.ttf
          weight: 500
        - asset: assets/fonts/CormorantGaramond-Italic.ttf
          weight: 400
          style: italic
    - family: JetBrainsMono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Regular.ttf
          weight: 400
        - asset: assets/fonts/JetBrainsMono-Medium.ttf
          weight: 500
```

- [ ] **Step 4: 安装 + 编译验证**

Run: `flutter pub get && flutter analyze`
Expected: pub resolve 通过，analyze clean。

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/fonts/
git commit -m "feat(theme): add window_manager dep + Cormorant Garamond / JetBrains Mono fonts"
```

---

## Task 2 — Typography 升级

**Files:**
- Modify: `lib/theme/typography.dart`
- Test: `test/theme/typography_test.dart`

- [ ] **Step 1: 读现有 InkTypography 当前结构**

Run: `cat lib/theme/typography.dart`
记下当前字段（body / title / display 等），保留兼容。

- [ ] **Step 2: 写失败测试**

打开 `test/theme/typography_test.dart`（不存在就建），加：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/typography.dart';

void main() {
  group('InkTypography Amber Noir', () {
    test('display uses CormorantGaramond Light', () {
      final t = InkTypography.defaults();
      expect(t.display.fontFamily, 'CormorantGaramond');
      expect(t.display.fontWeight, FontWeight.w300);
    });

    test('headline uses CormorantGaramond Regular 22pt', () {
      final t = InkTypography.defaults();
      expect(t.headline.fontFamily, 'CormorantGaramond');
      expect(t.headline.fontWeight, FontWeight.w400);
      expect(t.headline.fontSize, 22);
    });

    test('caption uses JetBrainsMono', () {
      final t = InkTypography.defaults();
      expect(t.caption.fontFamily, 'JetBrainsMono');
      expect(t.caption.fontSize, 11);
    });
  });
}
```

- [ ] **Step 3: Run failing test**

Run: `flutter test test/theme/typography_test.dart`
Expected: FAIL — 字段不存在 / fontFamily 不是。

- [ ] **Step 4: 实现 — 改 lib/theme/typography.dart**

加新字段 + fontFamily 配置。完整文件示例：

```dart
import 'package:flutter/material.dart';

@immutable
class InkTypography {
  const InkTypography._({
    required this.body,
    required this.title,
    required this.display,
    required this.headline,
    required this.caption,
    required this.micro,
    required this.nano,
  });

  factory InkTypography.defaults() => const InkTypography._(
        body: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400),
        title: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w500),
        display: TextStyle(fontFamily: 'CormorantGaramond', fontSize: 48, fontWeight: FontWeight.w300, letterSpacing: 0.5),
        headline: TextStyle(fontFamily: 'CormorantGaramond', fontSize: 22, fontWeight: FontWeight.w400),
        caption: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 1.5),
        micro: TextStyle(fontFamily: 'Inter', fontSize: 10),
        nano: TextStyle(fontFamily: 'Inter', fontSize: 9),
      );

  final TextStyle body;
  final TextStyle title;
  final TextStyle display;
  final TextStyle headline;
  final TextStyle caption;
  final TextStyle micro;
  final TextStyle nano;

  InkTypography scaled(double factor) => InkTypography._(
        body: body.copyWith(fontSize: body.fontSize! * factor),
        title: title.copyWith(fontSize: title.fontSize! * factor),
        display: display.copyWith(fontSize: display.fontSize! * factor),
        headline: headline.copyWith(fontSize: headline.fontSize! * factor),
        caption: caption.copyWith(fontSize: caption.fontSize! * factor),
        micro: micro.copyWith(fontSize: micro.fontSize! * factor),
        nano: nano.copyWith(fontSize: nano.fontSize! * factor),
      );
}
```

- [ ] **Step 5: Run tests pass**

Run: `flutter test test/theme/typography_test.dart && flutter test test/theme/tokens_test.dart`
Expected: All pass（注：旧的 `tokens_test.dart` 里 typography 相关断言可能因加字段需小幅调整，保留 size 断言通过）

- [ ] **Step 6: Commit**

```bash
git add lib/theme/typography.dart test/theme/typography_test.dart
git commit -m "feat(theme): add display/headline/caption fonts (Cormorant Garamond + JetBrains Mono)"
```

---

## Task 3 — InkNoirCard 原语

**Files:**
- Create: `lib/theme/primitives/ink_noir_card.dart`
- Test: `test/theme/primitives/ink_noir_card_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/theme/primitives/ink_noir_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_noir_card.dart';
import 'package:inkframe/theme/tokens.dart';

void main() {
  testWidgets('InkNoirCard uses surface2 bg + border 1px no shadow',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: const Scaffold(
        body: InkNoirCard(padding: EdgeInsets.all(8), child: Text('x')),
      ),
    ));
    final container = tester.widget<Container>(find.descendant(
      of: find.byType(InkNoirCard),
      matching: find.byType(Container),
    ).first);
    final deco = container.decoration as BoxDecoration;
    expect(deco.color, InkColors.dark().surface2);
    expect(deco.boxShadow, isNull);
    expect((deco.border as Border?)?.top.width, 1);
  });
}
```

- [ ] **Step 2: Run failing test**

Run: `flutter test test/theme/primitives/ink_noir_card_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: 实现**

```dart
// lib/theme/primitives/ink_noir_card.dart
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkNoirCard extends StatefulWidget {
  const InkNoirCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool selected;

  @override
  State<InkNoirCard> createState() => _InkNoirCardState();
}

class _InkNoirCardState extends State<InkNoirCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final borderColor = widget.selected
        ? colors.accent
        : _hover
            ? colors.borderHover
            : colors.border;
    final card = AnimatedContainer(
      duration: InkMotion.fast,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.lg),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: widget.child,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.onTap == null
          ? card
          : GestureDetector(onTap: widget.onTap, child: card),
    );
  }
}
```

- [ ] **Step 4: Run test pass**

Run: `flutter test test/theme/primitives/ink_noir_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/theme/primitives/ink_noir_card.dart test/theme/primitives/ink_noir_card_test.dart
git commit -m "feat(theme): add InkNoirCard primitive (matte black + 1px border, no blur)"
```

---

## Task 4 — InkAmberButton 原语

**Files:**
- Create: `lib/theme/primitives/ink_amber_button.dart`
- Test: `test/theme/primitives/ink_amber_button_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/theme/primitives/ink_amber_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_amber_button.dart';
import 'package:inkframe/theme/tokens.dart';

void main() {
  testWidgets('InkAmberButton uses cta bg + surfaceCanvas text + 44 height',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: InkAmberButton(
          label: 'Unlock',
          onPressed: () {},
        ),
      ),
    ));
    final box = tester.getSize(find.byType(InkAmberButton));
    expect(box.height, 44);
    expect(find.text('Unlock'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run failing test**

Run: `flutter test test/theme/primitives/ink_amber_button_test.dart`
Expected: FAIL.

- [ ] **Step 3: 实现**

```dart
// lib/theme/primitives/ink_amber_button.dart
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkAmberButton extends StatefulWidget {
  const InkAmberButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  State<InkAmberButton> createState() => _InkAmberButtonState();
}

class _InkAmberButtonState extends State<InkAmberButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final bg = _hover ? colors.ctaHover : colors.cta;
    final child = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(InkRadius.md),
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (widget.icon != null) ...<Widget>[
            Icon(widget.icon, size: 18, color: colors.surfaceCanvas),
            const SizedBox(width: InkSpacing.sm),
          ],
          Text(
            widget.label,
            style: typo.body.copyWith(
              color: colors.surfaceCanvas,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onPressed, child: child),
    );
  }
}
```

- [ ] **Step 4: Run test pass**

Run: `flutter test test/theme/primitives/ink_amber_button_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/theme/primitives/ink_amber_button.dart test/theme/primitives/ink_amber_button_test.dart
git commit -m "feat(theme): add InkAmberButton primitive (solid cta + 44h)"
```

---

## Task 5 — InkGhostButton 原语

**Files:**
- Create: `lib/theme/primitives/ink_ghost_button.dart`
- Test: `test/theme/primitives/ink_ghost_button_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/theme/primitives/ink_ghost_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_ghost_button.dart';

void main() {
  testWidgets('InkGhostButton has no background by default', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: InkGhostButton(label: 'Library', onPressed: () {}),
      ),
    ));
    expect(find.text('Library'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run failing test**

Run: `flutter test test/theme/primitives/ink_ghost_button_test.dart`
Expected: FAIL.

- [ ] **Step 3: 实现**

```dart
// lib/theme/primitives/ink_ghost_button.dart
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkGhostButton extends StatefulWidget {
  const InkGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  State<InkGhostButton> createState() => _InkGhostButtonState();
}

class _InkGhostButtonState extends State<InkGhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: InkMotion.fast,
          height: widget.compact ? 28 : 36,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? InkSpacing.sm : InkSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _hover ? colors.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(InkRadius.sm),
            border: Border.all(
              color: _hover ? colors.border : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 16, color: colors.fg2),
                const SizedBox(width: InkSpacing.xs),
              ],
              Text(widget.label, style: typo.body.copyWith(color: colors.fg2)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test pass**

Run: `flutter test test/theme/primitives/ink_ghost_button_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/theme/primitives/ink_ghost_button.dart test/theme/primitives/ink_ghost_button_test.dart
git commit -m "feat(theme): add InkGhostButton primitive (hover-only border)"
```

---

## Task 6 — Frameless 窗口 chrome

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/theme/components/ink_window_chrome.dart`
- Test: `test/theme/components/ink_window_chrome_test.dart`

- [ ] **Step 1: 写 chrome 组件测试**

```dart
// test/theme/components/ink_window_chrome_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_window_chrome.dart';

void main() {
  testWidgets('InkWindowChrome height is 56', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: const InkWindowChrome(
        center: Text('Studio › Projects'),
      ),
    ));
    final size = tester.getSize(find.byType(InkWindowChrome));
    expect(size.height, 56);
  });
}
```

- [ ] **Step 2: Run failing test**

Run: `flutter test test/theme/components/ink_window_chrome_test.dart`
Expected: FAIL.

- [ ] **Step 3: 实现 InkWindowChrome**

```dart
// lib/theme/components/ink_window_chrome.dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../app_theme.dart';
import '../tokens.dart';
import '../typography.dart';

class InkWindowChrome extends StatelessWidget {
  const InkWindowChrome({
    super.key,
    this.leading,
    this.center,
    this.trailing,
  });

  final Widget? leading;
  final Widget? center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return DragToMoveArea(
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: colors.surfaceCanvas,
          border: Border(
            bottom: BorderSide(color: colors.borderSubtle, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.lg),
        child: Row(
          children: <Widget>[
            if (leading != null) leading!,
            Expanded(child: Center(child: center ?? const SizedBox.shrink())),
            if (trailing != null) trailing!,
            const SizedBox(width: InkSpacing.md),
            const _WindowButtons(),
          ],
        ),
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _WinIconButton(icon: Icons.minimize, onPressed: () => windowManager.minimize()),
        _WinIconButton(icon: Icons.crop_square, onPressed: () async {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        }),
        _WinIconButton(icon: Icons.close, onPressed: () => windowManager.close(), danger: true),
      ],
    );
  }
}

class _WinIconButton extends StatefulWidget {
  const _WinIconButton({
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  State<_WinIconButton> createState() => _WinIconButtonState();
}

class _WinIconButtonState extends State<_WinIconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final bg = _hover
        ? (widget.danger ? colors.danger : colors.surface3)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 40,
          height: 32,
          color: bg,
          child: Icon(widget.icon, size: 14, color: colors.fg2),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 改 lib/main.dart 启动时 hide title bar**

在 `main()` 顶部加：

```dart
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const winOpts = WindowOptions(
    size: Size(1536, 984),
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Color(0xFF0B0908),
  );
  await windowManager.waitUntilReadyToShow(winOpts, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  // ... 现有 runApp 调用保留
}
```

- [ ] **Step 5: Run tests + smoke**

Run: `flutter test test/theme/components/ink_window_chrome_test.dart && flutter run -d windows`
Expected: test pass，窗口无系统标题栏，顶部 56px 自绘 chrome 出现，三按钮可拖+点击。

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/theme/components/ink_window_chrome.dart \
        test/theme/components/ink_window_chrome_test.dart
git commit -m "feat(theme): frameless window + custom 56px chrome"
```

---

## Task 7 — i18n keys 全量新增

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`

- [ ] **Step 1: 在两个 arb 文件加 keys**

新增 EN（`app_en.arb`）：

```json
"lockTagline": "A DESK FOR STORYBOARDERS",
"lockKeyPlaceholder": "Paste provider key...",
"lockKeyHelpLine1": "Get your API key from your provider dashboard.",
"lockKeyHelpLine2": "We never store your key on our servers.",
"lockUnlock": "Unlock",
"lockKeyInvalid": "Key invalid or network error. Try again.",
"studioRecentProjects": "Recent Projects",
"studioNewProject": "New Project",
"studioLibrary": "LIBRARY",
"studioArchive": "ARCHIVE",
"studioArchivedProjects": "Archived Projects",
"studioBreadcrumbAll": "All Projects",
"canvasInspectorTransform": "Transform",
"canvasInspectorCamera": "Camera",
"canvasInspectorComposition": "Composition",
"canvasInspectorMetadata": "Metadata",
"canvasInspectorNotes": "Notes",
"canvasInspectorAddAttribute": "Add Attribute",
"canvasRenderQueue": "Render Queue",
"canvasRenderQueueJobsRunning": "{count} jobs · {running} running"
```

ZH（`app_zh.arb`）写入对应中文译文。**两文件 key 集合必须完全一致**（CI hook 强制）。

- [ ] **Step 2: 跑 gen-l10n + i18n hook**

Run: `flutter gen-l10n && bash scripts/hooks/check-i18n-coverage.sh lib/l10n/app_en.arb`
Expected: 双语 key 集合一致 ✅。

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_zh.arb
git commit -m "feat(i18n): add keys for Lock + Studio + Canvas Amber Noir UI"
```

---

## Task 8 — Lock screen feature

**Files:**
- Create: `lib/features/lock/lock_screen.dart`
- Create: `lib/features/lock/controllers/lock_controller.dart`
- Create: `lib/features/lock/widgets/lock_logo.dart`
- Create: `lib/features/lock/widgets/lock_secure_field.dart`
- Modify: `lib/core/di/secure_storage.dart`（加 `apiKeyUnlockedProvider`）
- Test: `test/features/lock/lock_screen_test.dart`

- [ ] **Step 1: 加 apiKeyUnlockedProvider**

打开 `lib/core/di/secure_storage.dart`，append：

```dart
final apiKeyUnlockedProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageServiceProvider);
  for (final providerId in const <String>[
    'gemini-image', 'wanx-image', 'kling-v3',
  ]) {
    if (await storage.exists(SecureStorageKeys.providerApiKey(providerId))) {
      return true;
    }
  }
  return false;
});
```

- [ ] **Step 2: 写失败测试**

```dart
// test/features/lock/lock_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/lock/lock_screen.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/l10n/l10n_x.dart';

void main() {
  testWidgets('LockScreen renders logo + unlock CTA', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LockScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ink/Frame'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run failing test**

Run: `flutter test test/features/lock/lock_screen_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 4: 实现 LockLogo widget**

```dart
// lib/features/lock/widgets/lock_logo.dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/typography.dart';

class LockLogo extends StatelessWidget {
  const LockLogo({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return RichText(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(text: 'Ink', style: typo.display.copyWith(color: colors.fg1)),
          TextSpan(text: '/', style: typo.display.copyWith(color: colors.accent)),
          TextSpan(text: 'Frame', style: typo.display.copyWith(color: colors.fg1)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 实现 LockSecureField widget**

```dart
// lib/features/lock/widgets/lock_secure_field.dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class LockSecureField extends StatefulWidget {
  const LockSecureField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  State<LockSecureField> createState() => _LockSecureFieldState();
}

class _LockSecureFieldState extends State<LockSecureField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscure,
              autofocus: true,
              style: typo.body.copyWith(color: colors.fg1),
              decoration: InputDecoration.collapsed(
                hintText: widget.hintText,
                hintStyle: typo.body.copyWith(color: colors.fg3),
              ),
              onSubmitted: widget.onSubmitted,
            ),
          ),
          IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: colors.fg3,
              size: 20,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 实现 LockController**

```dart
// lib/features/lock/controllers/lock_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/secure_storage.dart';
import '../../../core/constants/secure_storage_keys.dart';

final lockControllerProvider =
    AsyncNotifierProvider<LockController, bool>(LockController.new);

class LockController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<bool> submit(String providerId, String key) async {
    state = const AsyncValue.loading();
    try {
      final storage = ref.read(secureStorageServiceProvider);
      await storage.store(SecureStorageKeys.providerApiKey(providerId), key);
      ref.invalidate(apiKeyUnlockedProvider);
      state = const AsyncValue.data(true);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
```

- [ ] **Step 7: 实现 LockScreen 主体**

```dart
// lib/features/lock/lock_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/primitives/ink_amber_button.dart';
import '../../theme/primitives/ink_ghost_button.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'controllers/lock_controller.dart';
import 'widgets/lock_logo.dart';
import 'widgets/lock_secure_field.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final TextEditingController _keyController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = context.l10n.lockKeyInvalid);
      return;
    }
    final ok = await ref
        .read(lockControllerProvider.notifier)
        .submit('gemini-image', key);
    if (!ok && mounted) {
      setState(() => _error = context.l10n.lockKeyInvalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      body: Stack(
        children: <Widget>[
          Positioned(
            left: -120,
            bottom: -200,
            child: Text(
              'I',
              style: typo.display.copyWith(
                fontSize: 800,
                color: colors.fg4.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: InkSpacing.lg,
            right: InkSpacing.lg,
            child: InkGhostButton(
              label: '中 / EN',
              onPressed: () {/* TODO: locale toggle */},
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const LockLogo(),
                  const SizedBox(height: InkSpacing.md),
                  Text(
                    context.l10n.lockTagline,
                    style: typo.caption.copyWith(color: colors.fg2),
                  ),
                  const SizedBox(height: InkSpacing.xxl),
                  LockSecureField(
                    controller: _keyController,
                    hintText: context.l10n.lockKeyPlaceholder,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: InkSpacing.md),
                  Text(context.l10n.lockKeyHelpLine1,
                      style: typo.caption.copyWith(color: colors.fg3)),
                  Text(context.l10n.lockKeyHelpLine2,
                      style: typo.caption.copyWith(color: colors.fg3)),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: InkSpacing.sm),
                    Text(_error!,
                        style: typo.caption.copyWith(color: colors.danger)),
                  ],
                  const SizedBox(height: InkSpacing.xl),
                  InkAmberButton(
                    label: context.l10n.lockUnlock,
                    onPressed: _submit,
                    expand: true,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: InkSpacing.lg,
            bottom: InkSpacing.lg,
            child: Text(
              'v0.14.2 -- 3f8c91a',
              style: typo.caption.copyWith(color: colors.fg4),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run test pass**

Run: `flutter test test/features/lock/lock_screen_test.dart`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/features/lock/ lib/core/di/secure_storage.dart test/features/lock/
git commit -m "feat(lock): Lock screen — serif logo + secure underline input + amber Unlock"
```

---

## Task 9 — Routing：根据 unlock 状态分流

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: 读 lib/app.dart 现有路由**

Run: `cat lib/app.dart`
确认 MaterialApp / go_router 配置位置。

- [ ] **Step 2: 加 redirect 接 apiKeyUnlockedProvider**

```dart
// lib/app.dart（关键片段）
final router = GoRouter(
  initialLocation: '/lock',
  redirect: (context, state) {
    final unlocked = ProviderScope.containerOf(context)
        .read(apiKeyUnlockedProvider)
        .valueOrNull ?? false;
    final atLock = state.matchedLocation == '/lock';
    if (!unlocked && !atLock) return '/lock';
    if (unlocked && atLock) return '/studio';
    return null;
  },
  routes: <RouteBase>[
    GoRoute(path: '/lock', builder: (_, __) => const LockScreen()),
    GoRoute(path: '/studio', builder: (_, __) => const StudioHomeScreen()),
    GoRoute(path: '/canvas/:id', builder: (_, s) =>
        CanvasScreen(canvasId: s.pathParameters['id']!)),
  ],
);
```

- [ ] **Step 3: Smoke 测试**

Run: `flutter test test/features/lock/`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/app.dart
git commit -m "feat(router): redirect to /lock until any provider key is stored"
```

---

## Task 10 — Studio Home 重写

**Files:**
- Create: `lib/features/studio/studio_home_screen.dart`
- Create: `lib/features/studio/widgets/library_sidebar.dart`
- Create: `lib/features/studio/widgets/project_card.dart`
- Create: `lib/features/studio/widgets/studio_top_chrome.dart`
- Create: `lib/features/studio/controllers/studio_state.dart`
- Delete: `lib/features/workspace/workspace_home_screen.dart` (Task 12 一并处理)
- Test: `test/features/studio/studio_home_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/studio/studio_home_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/l10n/l10n_x.dart';

void main() {
  testWidgets('StudioHome renders Library sidebar + Recent Projects header + New Project',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StudioHomeScreen(),
      ),
    ));
    await tester.pump();
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('Recent Projects'), findsOneWidget);
    expect(find.text('New Project'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run failing test**

Expected: FAIL — file missing.

- [ ] **Step 3: studio_state.dart**

```dart
// lib/features/studio/controllers/studio_state.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentStudioProvider = StateProvider<String>((_) => 'Kerro Studio');
final selectedProjectIdProvider = StateProvider<String?>((_) => null);
```

- [ ] **Step 4: studio_top_chrome.dart**

```dart
// lib/features/studio/widgets/studio_top_chrome.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../lock/widgets/lock_logo.dart';
import '../controllers/studio_state.dart';

class StudioTopChrome extends ConsumerWidget {
  const StudioTopChrome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final studio = ref.watch(currentStudioProvider);
    return InkWindowChrome(
      leading: const LockLogo(),
      center: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(studio, style: typo.body.copyWith(color: colors.fg2)),
          _Chevron(),
          Text('Projects', style: typo.body.copyWith(color: colors.fg2)),
          _Chevron(),
          Text('All Projects', style: typo.body.copyWith(color: colors.fg1)),
        ],
      ),
      trailing: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(InkRadius.sm),
            ),
            child: Text('⌘ K', style: typo.caption.copyWith(color: colors.fg2)),
          ),
          const SizedBox(width: InkSpacing.md),
          CircleAvatar(radius: 14, backgroundColor: colors.surface3),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
        child: Icon(Icons.chevron_right, size: 14, color: context.inkColors.fg3),
      );
}
```

- [ ] **Step 5: library_sidebar.dart**

```dart
// lib/features/studio/widgets/library_sidebar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../controllers/studio_state.dart';

class LibrarySidebar extends ConsumerWidget {
  const LibrarySidebar({super.key});
  static const double width = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final studio = ref.watch(currentStudioProvider);
    return Container(
      width: width,
      color: colors.surface1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: InkSpacing.lg),
          _Section(label: context.l10n.studioLibrary),
          _TreeNode(icon: Icons.folder_outlined, label: studio, count: 0, depth: 0),
          _TreeNode(icon: Icons.folder_open_outlined, label: 'Projects', count: 0, depth: 1, expanded: true),
          const Spacer(),
          _Section(label: context.l10n.studioArchive),
          _TreeNode(icon: Icons.inventory_2_outlined, label: context.l10n.studioArchivedProjects, count: 0, depth: 0),
          _BottomActions(),
          const SizedBox(height: InkSpacing.lg),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          InkSpacing.lg, InkSpacing.md, InkSpacing.lg, InkSpacing.sm,
        ),
        child: Text(
          label,
          style: context.inkTypography.caption.copyWith(
            color: context.inkColors.fg3,
            letterSpacing: 2,
          ),
        ),
      );
}

class _TreeNode extends StatelessWidget {
  const _TreeNode({
    required this.icon,
    required this.label,
    required this.count,
    required this.depth,
    this.expanded = false,
  });
  final IconData icon;
  final String label;
  final int count;
  final int depth;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      padding: EdgeInsets.fromLTRB(
        InkSpacing.lg + depth * 16.0,
        InkSpacing.sm,
        InkSpacing.lg,
        InkSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(expanded ? Icons.arrow_drop_down : Icons.arrow_right,
              size: 16, color: colors.fg3),
          const SizedBox(width: 4),
          Icon(icon, size: 16, color: colors.fg2),
          const SizedBox(width: InkSpacing.sm),
          Expanded(child: Text(label, style: typo.body.copyWith(color: colors.fg1))),
          if (count > 0)
            Text('$count', style: typo.caption.copyWith(color: colors.fg3)),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final icons = <IconData>[
      Icons.settings_outlined,
      Icons.archive_outlined,
      Icons.person_outline,
      Icons.delete_outline,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.lg),
      child: Row(
        children: <Widget>[
          for (final i in icons) ...<Widget>[
            Icon(i, size: 18, color: colors.fg3),
            const SizedBox(width: InkSpacing.md),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: project_card.dart**

```dart
// lib/features/studio/widgets/project_card.dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_noir_card.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.title,
    required this.episode,
    required this.date,
    required this.count,
  });
  final String title;
  final String episode;
  final String date;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return InkNoirCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface3,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(InkRadius.lg)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(InkSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: typo.headline.copyWith(color: colors.fg1)),
                const SizedBox(height: InkSpacing.xs),
                Text(
                  '$episode · $date · 📦 $count',
                  style: typo.caption.copyWith(color: colors.fg3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: studio_home_screen.dart**

```dart
// lib/features/studio/studio_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/primitives/ink_amber_button.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../workspace/workspace_home_screen.dart' show workspaceProjectsProvider;
import 'widgets/library_sidebar.dart';
import 'widgets/project_card.dart';
import 'widgets/studio_top_chrome.dart';

class StudioHomeScreen extends ConsumerWidget {
  const StudioHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final projectsAsync = ref.watch(workspaceProjectsProvider);
    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      body: Column(
        children: <Widget>[
          const StudioTopChrome(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const LibrarySidebar(),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(InkSpacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.studioRecentProjects,
                              style: typo.headline
                                  .copyWith(color: colors.fg1, fontSize: 28),
                            ),
                            const SizedBox(height: InkSpacing.lg),
                            Expanded(
                              child: projectsAsync.when(
                                loading: () => const Center(
                                    child: CircularProgressIndicator()),
                                error: (e, _) => Text('$e',
                                    style: typo.body.copyWith(color: colors.danger)),
                                data: (projects) => GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: InkSpacing.lg,
                                    mainAxisSpacing: InkSpacing.lg,
                                    childAspectRatio: 0.85,
                                  ),
                                  itemCount: projects.length,
                                  itemBuilder: (_, i) => ProjectCard(
                                    title: projects[i].name,
                                    episode: 'EP 01',
                                    date: '2026.05.13',
                                    count: projects[i].canvases.length,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: InkSpacing.xxl,
                        bottom: InkSpacing.xxl,
                        child: InkAmberButton(
                          label: context.l10n.studioNewProject,
                          icon: Icons.add,
                          onPressed: () {/* TODO new project dialog */},
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run test pass**

Run: `flutter test test/features/studio/`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/features/studio/ test/features/studio/
git commit -m "feat(studio): Studio Home — left tree sidebar + 4-col project grid + amber FAB"
```

---

## Task 11 — Canvas 视觉重写

**Files:**
- Create: `lib/features/canvas/widgets/canvas_node_card.dart`
- Create: `lib/features/canvas/widgets/canvas_inspector.dart`
- Create: `lib/features/canvas/widgets/canvas_render_queue.dart`
- Create: `lib/features/canvas/widgets/canvas_top_chrome.dart`
- Create: `lib/features/canvas/widgets/canvas_left_toolbar.dart`
- Modify: `lib/features/canvas/widgets/canvas_screen.dart`（compose 新组件）
- Test: `test/features/canvas/widgets/canvas_node_card_test.dart`

- [ ] **Step 1: 写节点卡 widget 测试**

```dart
// test/features/canvas/widgets/canvas_node_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_node_card.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('CanvasNodeCard shows type strip + Cormorant title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: const Scaffold(
        body: CanvasNodeCard(
          type: CanvasNodeType.character,
          title: 'Elara',
          id: 'chr_0042',
          resolution: '1024x576',
        ),
      ),
    ));
    expect(find.text('Elara'), findsOneWidget);
    expect(find.text('Character'), findsOneWidget);
    expect(find.text('chr_0042'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run failing test**

Expected: FAIL.

- [ ] **Step 3: 实现 CanvasNodeCard**

```dart
// lib/features/canvas/widgets/canvas_node_card.dart
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_noir_card.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

enum CanvasNodeType { character, scene, camera, prop, shot, imageGen }

extension CanvasNodeTypeX on CanvasNodeType {
  String get label => switch (this) {
        CanvasNodeType.character => 'Character',
        CanvasNodeType.scene => 'Scene',
        CanvasNodeType.camera => 'Camera',
        CanvasNodeType.prop => 'Prop',
        CanvasNodeType.shot => 'Shot',
        CanvasNodeType.imageGen => 'Image Gen',
      };

  Color stripeColor(InkColors c) => switch (this) {
        CanvasNodeType.character => c.accent,
        CanvasNodeType.scene => c.info,
        CanvasNodeType.camera => c.warning,
        CanvasNodeType.prop => c.danger,
        CanvasNodeType.shot => c.border,
        CanvasNodeType.imageGen => c.success,
      };
}

class CanvasNodeCard extends StatelessWidget {
  const CanvasNodeCard({
    super.key,
    required this.type,
    required this.title,
    required this.id,
    required this.resolution,
    this.selected = false,
  });
  final CanvasNodeType type;
  final String title;
  final String id;
  final String resolution;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return SizedBox(
      width: 200,
      child: InkNoirCard(
        selected: selected,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(height: 4, color: type.stripeColor(colors)),
            Padding(
              padding: const EdgeInsets.all(InkSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(type.label,
                      style: typo.caption.copyWith(color: colors.fg3)),
                  const SizedBox(height: 2),
                  Text(title,
                      style: typo.headline
                          .copyWith(color: colors.fg1, fontSize: 16)),
                  const SizedBox(height: InkSpacing.sm),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surface3,
                        borderRadius: BorderRadius.circular(InkRadius.sm),
                      ),
                    ),
                  ),
                  const SizedBox(height: InkSpacing.sm),
                  _MonoRow(label: 'ID', value: id),
                  _MonoRow(label: 'RES', value: resolution),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonoRow extends StatelessWidget {
  const _MonoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Text(label, style: t.caption.copyWith(color: c.fg3)),
          ),
          Text(value, style: t.caption.copyWith(color: c.fg1)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 实现 canvas_inspector.dart**

(下方先建一个最小可用版本 — 顶部节点 name + ID + 5 个折叠组占位 + Add Attribute 链接。完整 spec 见 §3.3。)

```dart
// lib/features/canvas/widgets/canvas_inspector.dart
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

class CanvasInspector extends StatelessWidget {
  const CanvasInspector({
    super.key,
    required this.nodeTitle,
    required this.nodeKindLabel,
    required this.nodeId,
  });
  final String nodeTitle;
  final String nodeKindLabel;
  final String nodeId;

  static const double width = 320;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(left: BorderSide(color: colors.borderSubtle)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(InkSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(nodeTitle, style: typo.headline.copyWith(color: colors.fg1)),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Text(nodeKindLabel,
                    style: typo.caption.copyWith(color: colors.fg3)),
                const SizedBox(width: InkSpacing.md),
                Text('ID', style: typo.caption.copyWith(color: colors.fg3)),
                const SizedBox(width: 4),
                Text(nodeId, style: typo.caption.copyWith(color: colors.fg2)),
              ],
            ),
            const SizedBox(height: InkSpacing.lg),
            _CollapseSection(label: context.l10n.canvasInspectorTransform, child: const SizedBox(height: 100)),
            _CollapseSection(label: context.l10n.canvasInspectorCamera, child: const SizedBox(height: 200)),
            _CollapseSection(label: context.l10n.canvasInspectorComposition, child: const SizedBox(height: 100)),
            _CollapseSection(label: context.l10n.canvasInspectorMetadata, child: const SizedBox(height: 80)),
            _CollapseSection(label: context.l10n.canvasInspectorNotes, child: const SizedBox(height: 60)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: InkSpacing.md),
              child: Row(
                children: <Widget>[
                  Icon(Icons.add, size: 16, color: colors.accent),
                  const SizedBox(width: InkSpacing.xs),
                  Text(context.l10n.canvasInspectorAddAttribute,
                      style: typo.body.copyWith(color: colors.accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapseSection extends StatefulWidget {
  const _CollapseSection({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  State<_CollapseSection> createState() => _CollapseSectionState();
}

class _CollapseSectionState extends State<_CollapseSection> {
  bool _open = true;
  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: InkSpacing.sm),
            child: Row(
              children: <Widget>[
                Icon(_open ? Icons.expand_more : Icons.chevron_right,
                    size: 16, color: c.fg2),
                const SizedBox(width: 4),
                Text(widget.label, style: t.body.copyWith(color: c.fg1)),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(left: 20),
            child: widget.child,
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: canvas_render_queue.dart**

```dart
// lib/features/canvas/widgets/canvas_render_queue.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

class CanvasRenderQueue extends ConsumerWidget {
  const CanvasRenderQueue({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      padding: const EdgeInsets.all(InkSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(context.l10n.canvasRenderQueue,
                    style: typo.headline.copyWith(color: colors.fg1)),
              ),
              Text('3 jobs · 2 running',
                  style: typo.caption.copyWith(color: colors.fg3)),
            ],
          ),
          const SizedBox(height: InkSpacing.md),
          // 占位三行
          for (final pair in const <(String, int)>[
            ('Watch Closeup', 45),
            ('Harbor Docks', 18),
            ('Nocturne Teaser', 0),
          ])
            _JobRow(title: pair.$1, percent: pair.$2),
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.title, required this.percent});
  final String title;
  final int percent;
  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(title, style: t.body.copyWith(color: c.fg1))),
              Text(percent == 0 ? 'Queued' : '$percent%',
                  style: t.caption.copyWith(color: c.fg2)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 4,
              backgroundColor: c.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(c.accent),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: canvas_top_chrome + canvas_left_toolbar**

(留给执行 agent 按 spec §3.3 实现，结构与 StudioTopChrome 类似，breadcrumb 字符串改为 `Project › Nocturne › Episode 02 › Canvas`，trailing 加 `⌘ K` + `▶` icon + avatar。)

Left toolbar 56px 宽：select / pan / box / connect / shape / text / image / 3d 等竖排 ICON IconButton。

- [ ] **Step 7: 改 canvas_screen.dart compose 新组件**

读取现有 `lib/features/canvas/widgets/canvas_screen.dart`，把外壳改为：

```
Column
├── CanvasTopChrome
└── Expanded
    └── Row
        ├── CanvasLeftToolbar (56)
        ├── Expanded: NodeViewport (现有)
        └── Column (right pane width 320)
            ├── Expanded(flex: 2): CanvasInspector
            └── Expanded(flex: 1): CanvasRenderQueue
```

节点画布内部把 `XxxNodeWidget` 替换为 `CanvasNodeCard`。

- [ ] **Step 8: Run test pass**

Run: `flutter test test/features/canvas/widgets/canvas_node_card_test.dart`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add lib/features/canvas/widgets/ test/features/canvas/widgets/
git commit -m "feat(canvas): visual rewrite — type-coded node cards + Inspector + Render Queue"
```

---

## Task 12 — 废弃旧 primitives + 清理

**Files:**
- Delete: `lib/theme/primitives/ink_glass_card.dart`
- Delete: `lib/theme/primitives/ink_gradient_button.dart`
- Delete: `lib/theme/primitives/ink_pill_tag.dart`
- Delete: `lib/features/workspace/workspace_home_screen.dart`（被 studio 替代后）
- Modify: 所有原引用这三个文件 / workspace_home_screen 的地方

- [ ] **Step 1: grep 找所有引用**

Run: `grep -rn "InkGlassCard\|InkGradientButton\|InkPillTag\|workspace_home_screen" lib/ test/ | grep -v primitives/ink_glass_card.dart | grep -v primitives/ink_gradient_button.dart | grep -v primitives/ink_pill_tag.dart`
记下命中点。

- [ ] **Step 2: 逐文件改 import 与用法**

每个命中点把：
- `InkGlassCard` → `InkNoirCard`
- `InkGradientButton` → `InkAmberButton`
- `InkPillTag` → `Container` + 1px border + caption text（无替代 primitive，inline 即可）
- `workspaceProjectsProvider` 仍保留（不动 provider，只删 UI）

- [ ] **Step 3: 删旧文件**

```bash
rm lib/theme/primitives/ink_glass_card.dart
rm lib/theme/primitives/ink_gradient_button.dart
rm lib/theme/primitives/ink_pill_tag.dart
rm lib/features/workspace/workspace_home_screen.dart
```

（注意：`workspaceProjectsProvider` 若还有外部消费，先迁到 `lib/features/studio/controllers/`，再删 file。）

- [ ] **Step 4: Run full test suite**

Run: `flutter analyze && flutter test`
Expected: clean + green。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(theme): delete deprecated glass/gradient/pill primitives + old workspace screen"
```

---

## Task 13 — 最终联调 + 验收

- [ ] **Step 1: 杀僵尸 pg + 启动 app**

```bash
powershell.exe -Command "Get-Process postgres -ErrorAction SilentlyContinue | Stop-Process -Force"
rm -f /c/Users/kerro/InkFrame/database/postmaster.pid
flutter run -d windows
```

- [ ] **Step 2: 手动走 §8 验收清单**

对照 spec §8 5 条：
1. Lock 屏第一帧 vs `首页登录.png`（视觉偏差 < 5%）
2. Studio Home vs `首页.png`（左树 / 卡网格 / FAB）
3. Canvas vs `画布.png` + `任务队列.png`
4. Windows 跑通 frameless
5. 旧 primitives 零引用 — `grep -rn "InkGlassCard\|InkGradientButton\|InkPillTag" lib/` 空命中

- [ ] **Step 3: 修复手动测试发现的视觉偏差**

按 spec §3 逐屏对照，每发现一处不符开一个小 commit `fix(ui): ...`。

- [ ] **Step 4: CI 全绿确认**

Push 分支等 CI 跑：

```bash
git push -u origin feat/ui-amber-noir-rebrand
```

确认 `analyze + hooks` / `test + coverage` / `golden` / `gitleaks` 4 项全 PASS。

- [ ] **Step 5: 开 PR**

```bash
gh pr create --base main --title "feat(ui): Amber Noir UI rebrand — Lock + Studio + Canvas + frameless" --body "<参照 spec §1 + 验收 checklist>"
```

---

## 出现问题时

- **字体加载失败 / 中文不显示**：检查 `pubspec.yaml` assets/fonts 段缩进；Cormorant 不含 CJK，CJK 走 Inter 回退（fontFamilyFallback: ['Noto Sans CJK', system-cjk-sans]）
- **window_manager 在 Windows 上 chrome 高度异常**：DPI 缩放，用 `MediaQuery.of(context).devicePixelRatio` 校准
- **frameless 后 macOS traffic light 仍显**：`windowManager.setTitleBarStyle(TitleBarStyle.hidden)` 必须在 `runApp` 之前；如残留需 `windowManager.hideTitleBar()` 双保险
- **路由 redirect 无限循环**：`apiKeyUnlockedProvider` 用 FutureProvider 时 `valueOrNull` 在初始 loading 会是 null，需先 await loading 完再 redirect
- **i18n key 漏写**：`scripts/hooks/check-i18n-coverage.sh` 会 reject commit，按提示补
- **测试 InkNoirCard hover 触发不了 MouseRegion**：用 `tester.binding.handlePointerEvent` 模拟 mouse hover；或用 `WidgetTester.dragFrom` 简化场景
- **node card 重叠**：CanvasNodeCard 默认 width 200，画布 layout 需自己用 Positioned 摆位置（保留现有 canvas viewport 摆位逻辑）
