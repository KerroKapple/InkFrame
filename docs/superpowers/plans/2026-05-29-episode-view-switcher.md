# Episode View Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Canvas/Episode 工作区顶栏加入「跨视图切换栏」（Canvas / Storyboard / Script / Generation / Queue），并让正文按所选视图切换；非 Canvas 视图先以占位屏承载，供后续 04–08 计划逐一替换。

**Architecture:** 新增 `EpisodeView` 枚举 + `currentEpisodeViewProvider`（StateProvider）作为单一真相源。表现层新增无状态展示组件 `EpisodeViewNav`（复刻 mockup `.view-nav`：等宽 11px、active=accent+surface2、hover=fg1+surface2），嵌入 `CanvasTopChrome` 的 center 槽（breadcrumb 之后）。`CanvasScreen` 监听该 provider，Canvas 视图渲染既有布局，其余视图渲染 `EpisodeViewPlaceholder`。切换栏只在 Canvas 壳内出现（`CanvasScreen` 仅当 `currentCanvasId != null` 时由 `app.dart` 渲染）。

**Tech Stack:** Flutter (Material) · Riverpod (StateProvider) · flutter_test (widget tests) · flutter gen-l10n (ARB 本地化代码生成)。

**设计依据（mockup）：** `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/_components.js` 的 `EPISODE_VIEWS`（顺序：Canvas, Storyboard, Script, Generation, Queue）+ `_shared.css` 的 `.chrome .view-nav` 规则（`gap:2px; margin-left:18px; mono 11px; a{padding:5px 10px; radius r-sm; color fg-3} a:hover{fg-1 / surface-2} a.active{accent / surface-2}`）。

**约定（务必遵守）：**
- 真实代码库根目录是 `/Users/kerro/Projects/InkFrame`（不是当前 shell 的 cwd）。所有路径相对该根。
- 全程 `flutter`（项目用 Flutter 工具链；本计划不涉及 Python，不用 uv）。
- 注释中文、精简。用户可见文案走 l10n（en + zh 双份）。
- 测试踩坑须知：① 不要在 widget test 里 pump 含 `StoragePathSection` 的整屏（Ink* ticker 会留 pending frame → isolate 10 分钟超时）；本计划的 CanvasScreen 测试通过把视图设为非 Canvas 来**避开** `CanvasView` 重路径。② `InkWindowChrome` 包了 `DragToMoveArea`，其 `onDoubleTap` 把单击识别延迟 `kDoubleTapTimeout`(300ms)——点击后须 `pump(const Duration(milliseconds: 350))` 让单击落地。

---

## File Structure

- **Create** `lib/features/canvas/providers/current_episode_view.dart` — `EpisodeView` 枚举 + `currentEpisodeViewProvider`。单一职责：当前视图状态。
- **Create** `lib/features/canvas/widgets/episode_view_nav.dart` — `EpisodeViewNav` 展示组件 + 内部 `_ViewTab`。单一职责：渲染切换栏并在点击时写 provider。
- **Create** `lib/features/canvas/widgets/episode_view_placeholder.dart` — `EpisodeViewPlaceholder`：非 Canvas 视图的占位屏。
- **Modify** `lib/features/canvas/widgets/canvas_top_chrome.dart` — center 槽改为 `Row[Breadcrumb, EpisodeViewNav]`。
- **Modify** `lib/features/canvas/widgets/canvas_screen.dart` — 监听 `currentEpisodeViewProvider`，正文与 FAB 按视图切换。
- **Modify** `lib/l10n/app_en.arb` + `lib/l10n/app_zh.arb` — 新增 5 个视图标签 + 占位文案。
- **Test** `test/features/canvas/providers/current_episode_view_test.dart`
- **Test** `test/features/canvas/widgets/episode_view_nav_test.dart`
- **Test** `test/features/canvas/widgets/episode_view_placeholder_test.dart`
- **Test** `test/features/canvas/widgets/canvas_screen_view_switch_test.dart`

---

### Task 1: EpisodeView 状态模型

**Files:**
- Create: `lib/features/canvas/providers/current_episode_view.dart`
- Test: `test/features/canvas/providers/current_episode_view_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/canvas/providers/current_episode_view_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_episode_view.dart';

void main() {
  test('默认视图为 canvas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(currentEpisodeViewProvider), EpisodeView.canvas);
  });

  test('EpisodeView 顺序与 mockup EPISODE_VIEWS 一致', () {
    expect(EpisodeView.values, <EpisodeView>[
      EpisodeView.canvas,
      EpisodeView.storyboard,
      EpisodeView.script,
      EpisodeView.generation,
      EpisodeView.queue,
    ]);
  });

  test('可切换视图', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(currentEpisodeViewProvider.notifier).state =
        EpisodeView.storyboard;
    expect(container.read(currentEpisodeViewProvider), EpisodeView.storyboard);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/providers/current_episode_view_test.dart`
Expected: 编译失败 —— `Error: ... 'current_episode_view.dart': No such file`（RED）。

- [ ] **Step 3: 写最小实现**

```dart
// lib/features/canvas/providers/current_episode_view.dart
// currentEpisodeViewProvider — Canvas/Episode 工作区当前展示的视图。
// 顺序对齐 mockup _components.js 的 EPISODE_VIEWS。
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EpisodeView { canvas, storyboard, script, generation, queue }

final currentEpisodeViewProvider = StateProvider<EpisodeView>(
  (ref) => EpisodeView.canvas,
  name: 'currentEpisodeViewProvider',
);
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/providers/current_episode_view_test.dart`
Expected: `All tests passed!`（3 passed）

- [ ] **Step 5: 提交**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/canvas/providers/current_episode_view.dart test/features/canvas/providers/current_episode_view_test.dart
git commit -m "feat(canvas): add EpisodeView state provider"
```

---

### Task 2: 本地化标签

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`

> 说明：l10n 是代码生成，无独立单元测试；验证 = `flutter gen-l10n` 成功 + 后续 Task 3/5 的 widget 测试引用这些 getter 能编译通过。新增键放在已有 `canvasBreadcrumb*` 键附近，保持文件分组。

- [ ] **Step 1: 在 `lib/l10n/app_en.arb` 的 `"canvasBackToStudio"` 条目之后插入**

```json
  "episodeViewCanvas": "Canvas",
  "episodeViewStoryboard": "Storyboard",
  "episodeViewScript": "Script",
  "episodeViewGeneration": "Generation",
  "episodeViewQueue": "Queue",
  "episodeViewComingSoon": "{view} view is under construction.",
  "@episodeViewComingSoon": {
    "placeholders": { "view": { "type": "String" } }
  },
```

- [ ] **Step 2: 在 `lib/l10n/app_zh.arb` 的对应位置插入**

```json
  "episodeViewCanvas": "画布",
  "episodeViewStoryboard": "分镜",
  "episodeViewScript": "剧本",
  "episodeViewGeneration": "生成",
  "episodeViewQueue": "队列",
  "episodeViewComingSoon": "{view} 视图建设中。",
```

- [ ] **Step 3: 重新生成本地化代码**

Run: `cd /Users/kerro/Projects/InkFrame && flutter gen-l10n`
Expected: 无报错；`lib/l10n/generated/app_localizations.dart` 出现 `episodeViewCanvas` 等 getter。

- [ ] **Step 4: 校验生成结果**

Run: `cd /Users/kerro/Projects/InkFrame && grep -c "episodeViewStoryboard" lib/l10n/generated/app_localizations_en.dart`
Expected: 输出 `1`（或更大，非 0）。

- [ ] **Step 5: 提交**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/generated/
git commit -m "feat(l10n): add episode view switcher labels"
```

---

### Task 3: EpisodeViewNav 切换栏组件

**Files:**
- Create: `lib/features/canvas/widgets/episode_view_nav.dart`
- Test: `test/features/canvas/widgets/episode_view_nav_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/canvas/widgets/episode_view_nav_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_episode_view.dart';
import 'package:inkframe/features/canvas/widgets/episode_view_nav.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

Widget _wrap(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1.0),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: EpisodeViewNav())),
      ),
    );

void main() {
  testWidgets('渲染全部 5 个视图标签', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();
    for (final label in <String>['Canvas', 'Storyboard', 'Script', 'Generation', 'Queue']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('点击 Storyboard 标签切换 currentEpisodeViewProvider', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();
    expect(c.read(currentEpisodeViewProvider), EpisodeView.canvas);
    await tester.tap(find.byKey(EpisodeViewNav.tabKey(EpisodeView.storyboard)));
    await tester.pump();
    expect(c.read(currentEpisodeViewProvider), EpisodeView.storyboard);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/episode_view_nav_test.dart`
Expected: 编译失败 —— `Error: ... 'episode_view_nav.dart': No such file`（RED）。

> 注：此组件**不**在 `InkWindowChrome` 内（测试用普通 `Center` 包裹），故无 `DragToMoveArea` 的 300ms 延迟，`pump()` 单帧即可。

- [ ] **Step 3: 写最小实现**

```dart
// lib/features/canvas/widgets/episode_view_nav.dart
// EpisodeViewNav：跨视图切换栏（复刻 mockup .view-nav）。
// 等宽 11px；active=accent+surface2，hover=fg1+surface2，常态 fg3。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/current_episode_view.dart';

class EpisodeViewNav extends ConsumerWidget {
  const EpisodeViewNav({super.key});

  static Key tabKey(EpisodeView view) => Key('episode.viewNav.${view.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentEpisodeViewProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final view in EpisodeView.values) ...<Widget>[
          _ViewTab(
            view: view,
            label: _label(context, view),
            active: view == current,
            onTap: () =>
                ref.read(currentEpisodeViewProvider.notifier).state = view,
          ),
          if (view != EpisodeView.values.last) const SizedBox(width: 2),
        ],
      ],
    );
  }

  String _label(BuildContext context, EpisodeView view) {
    final l = context.l10n;
    return switch (view) {
      EpisodeView.canvas => l.episodeViewCanvas,
      EpisodeView.storyboard => l.episodeViewStoryboard,
      EpisodeView.script => l.episodeViewScript,
      EpisodeView.generation => l.episodeViewGeneration,
      EpisodeView.queue => l.episodeViewQueue,
    };
  }
}

class _ViewTab extends StatefulWidget {
  const _ViewTab({
    required this.view,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final EpisodeView view;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ViewTab> createState() => _ViewTabState();
}

class _ViewTabState extends State<_ViewTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final Color fg = widget.active
        ? colors.accent
        : _hover
            ? colors.fg1
            : colors.fg3;
    final Color bg =
        (widget.active || _hover) ? colors.surface2 : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          key: EpisodeViewNav.tabKey(widget.view),
          duration: InkMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: InkSpacing.sm + 2, // 10
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(InkRadius.sm),
          ),
          child: Text(
            widget.label,
            style: typo.caption.copyWith(color: fg, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/episode_view_nav_test.dart`
Expected: `All tests passed!`（2 passed）

- [ ] **Step 5: 提交**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/canvas/widgets/episode_view_nav.dart test/features/canvas/widgets/episode_view_nav_test.dart
git commit -m "feat(canvas): add EpisodeViewNav switcher widget"
```

---

### Task 4: 把切换栏嵌入 CanvasTopChrome

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_top_chrome.dart`（`CanvasTopChrome.build` 的 `center` 槽，约 22–31 行）
- Test: `test/features/canvas/widgets/canvas_top_chrome_test.dart`（在现有文件追加用例）

- [ ] **Step 1: 追加失败测试**

在 `test/features/canvas/widgets/canvas_top_chrome_test.dart` 的 `main()` 内追加（文件顶部若缺以下 import 则补上 `import 'package:inkframe/features/canvas/widgets/episode_view_nav.dart';`）：

```dart
  testWidgets('CanvasTopChrome 含 EpisodeViewNav', (tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1.0),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CanvasTopChrome(canvasName: 'Ep 02')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EpisodeViewNav), findsOneWidget);
  });
```

> 若现有测试文件未导入 `buildAppTheme` / `InkThemeVariant` / `AppLocalizations` / `currentCanvasIdProvider`，参照该文件其余用例已有的 import 即可（它们已在用）。

- [ ] **Step 2: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/canvas_top_chrome_test.dart`
Expected: 新用例 FAIL —— `Expected: exactly one matching candidate / Actual: _ZeroWidgetsFinder ... found 0`（RED）。

- [ ] **Step 3: 改 CanvasTopChrome 的 center 槽**

将 `lib/features/canvas/widgets/canvas_top_chrome.dart` 顶部 import 区加入：

```dart
import 'episode_view_nav.dart';
```

把 `build` 里的：

```dart
      center: _Breadcrumb(canvasName: canvasName),
```

改为：

```dart
      center: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(child: _Breadcrumb(canvasName: canvasName)),
          const SizedBox(width: InkSpacing.lg),
          const EpisodeViewNav(),
        ],
      ),
```

- [ ] **Step 4: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/canvas_top_chrome_test.dart`
Expected: `All tests passed!`（含既有用例与新用例）

- [ ] **Step 5: 提交**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/canvas/widgets/canvas_top_chrome.dart test/features/canvas/widgets/canvas_top_chrome_test.dart
git commit -m "feat(canvas): mount EpisodeViewNav in canvas chrome"
```

---

### Task 5: 占位屏 + CanvasScreen 正文按视图切换

**Files:**
- Create: `lib/features/canvas/widgets/episode_view_placeholder.dart`
- Modify: `lib/features/canvas/widgets/canvas_screen.dart`（`build` 的 `floatingActionButton` 与 `body` 的 `Expanded` 子树）
- Test: `test/features/canvas/widgets/episode_view_placeholder_test.dart`
- Test: `test/features/canvas/widgets/canvas_screen_view_switch_test.dart`

- [ ] **Step 1: 写占位屏失败测试**

```dart
// test/features/canvas/widgets/episode_view_placeholder_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_episode_view.dart';
import 'package:inkframe/features/canvas/widgets/episode_view_placeholder.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('占位屏显示视图标签', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1.0),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EpisodeViewPlaceholder(view: EpisodeView.storyboard),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Storyboard'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/episode_view_placeholder_test.dart`
Expected: 编译失败 —— `'episode_view_placeholder.dart': No such file`（RED）。

- [ ] **Step 3: 写占位屏实现**

```dart
// lib/features/canvas/widgets/episode_view_placeholder.dart
// EpisodeViewPlaceholder：非 Canvas 视图的占位屏，后续 04–08 计划逐一替换。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/current_episode_view.dart';

class EpisodeViewPlaceholder extends StatelessWidget {
  const EpisodeViewPlaceholder({super.key, required this.view});

  final EpisodeView view;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final label = switch (view) {
      EpisodeView.canvas => l.episodeViewCanvas,
      EpisodeView.storyboard => l.episodeViewStoryboard,
      EpisodeView.script => l.episodeViewScript,
      EpisodeView.generation => l.episodeViewGeneration,
      EpisodeView.queue => l.episodeViewQueue,
    };
    return ColoredBox(
      color: colors.surfaceCanvas,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.construction_outlined, size: 32, color: colors.fg4),
            const SizedBox(height: InkSpacing.md),
            Text(
              l.episodeViewComingSoon(label),
              style: typo.body.copyWith(color: colors.fg3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/episode_view_placeholder_test.dart`
Expected: `All tests passed!`（1 passed）

- [ ] **Step 5: 写 CanvasScreen 切换失败测试**

> 关键：把视图设为 `storyboard`，正文走占位屏分支，**不**构建 `CanvasView`（从而避开其数据/媒体重依赖与潜在 ticker hang）。

```dart
// test/features/canvas/widgets/canvas_screen_view_switch_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/current_episode_view.dart';
import 'package:inkframe/features/canvas/widgets/canvas_screen.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/episode_view_placeholder.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('非 Canvas 视图渲染占位屏而非 CanvasView', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: <Override>[
        currentCanvasIdProvider.overrideWith((ref) => 'c1'),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentEpisodeViewProvider.notifier).state =
        EpisodeView.storyboard;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1.0),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CanvasScreen(canvasName: 'Ep 02'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(EpisodeViewPlaceholder), findsOneWidget);
    expect(find.byType(CanvasView), findsNothing);
  });
}
```

- [ ] **Step 6: 运行确认失败**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/canvas_screen_view_switch_test.dart`
Expected: FAIL —— 当前 `CanvasScreen` 恒建 `CanvasView`，故 `EpisodeViewPlaceholder` 找到 0 个、`CanvasView` 找到 1 个（RED）。

- [ ] **Step 7: 改 CanvasScreen 按视图切换正文与 FAB**

把 `lib/features/canvas/widgets/canvas_screen.dart` 顶部 import 区加入：

```dart
import '../providers/current_episode_view.dart';
import 'episode_view_placeholder.dart';
```

`build` 内在 `final canvasId = ...` 之后加入：

```dart
    final view = ref.watch(currentEpisodeViewProvider);
```

`floatingActionButton` 改为（仅 Canvas 视图且有 canvasId 才显示 FAB）：

```dart
      floatingActionButton: (canvasId == null || view != EpisodeView.canvas)
          ? null
          : CanvasAddNodeFab(canvasId: canvasId),
```

把 `body` 里 `CanvasTopChrome` 之后的 `Expanded(child: Row(...))` 整块替换为：

```dart
          Expanded(
            child: view == EpisodeView.canvas
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const CanvasLeftToolbar(),
                      const Expanded(child: CanvasView()),
                      SizedBox(
                        width: 320,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: CanvasInspector(
                                nodeTitle: l.canvasInspectorMockTitle,
                                nodeKindLabel: l.canvasInspectorKindCamera,
                                nodeId: l.canvasInspectorMockId,
                              ),
                            ),
                            const Expanded(flex: 1, child: CanvasRenderQueue()),
                          ],
                        ),
                      ),
                    ],
                  )
                : EpisodeViewPlaceholder(view: view),
          ),
```

- [ ] **Step 8: 运行确认通过**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test test/features/canvas/widgets/canvas_screen_view_switch_test.dart`
Expected: `All tests passed!`（1 passed）

- [ ] **Step 9: 提交**

```bash
cd /Users/kerro/Projects/InkFrame
git add lib/features/canvas/widgets/episode_view_placeholder.dart lib/features/canvas/widgets/canvas_screen.dart test/features/canvas/widgets/episode_view_placeholder_test.dart test/features/canvas/widgets/canvas_screen_view_switch_test.dart
git commit -m "feat(canvas): switch canvas body by episode view"
```

---

### Task 6: 全量回归 + 静态检查

**Files:** 无（仅验证）

- [ ] **Step 1: 静态分析**

Run: `cd /Users/kerro/Projects/InkFrame && flutter analyze lib/features/canvas lib/l10n`
Expected: `No issues found!`

- [ ] **Step 2: 全量测试**

Run: `cd /Users/kerro/Projects/InkFrame && flutter test`
Expected: `All tests passed!`，通过数 = 改动前基线 + 本计划新增（current_episode_view 3 + episode_view_nav 2 + canvas_top_chrome +1 + episode_view_placeholder 1 + canvas_screen_view_switch 1 = 净增 8），跳过数不变。

- [ ] **Step 3: 若 Step 2 通过则收尾**

无新提交（前序任务已分别提交）。向用户汇报：基线→现通过数、analyze 结果，并提示「非 Canvas 视图当前为占位屏，04–08 各视图为后续独立计划」。

---

## Self-Review

**1. Spec coverage（对照 mockup 切换栏需求）：**
- 5 个视图 + 顺序（Canvas/Storyboard/Script/Generation/Queue）→ Task 1（枚举顺序断言）+ Task 2（标签）。✓
- `.view-nav` 视觉（mono 11、active=accent+surface2、hover=fg1+surface2、padding 5×10、radius sm、tab 间距 2）→ Task 3 `_ViewTab`。✓
- 切换栏位于顶栏 → Task 4 嵌入 `CanvasTopChrome.center`。✓
- 点击切换视图 → Task 3（provider 写入）+ Task 5（正文响应）。✓
- 非 Canvas 视图先占位、供后续替换 → Task 5 `EpisodeViewPlaceholder`。✓

**2. Placeholder scan：** 每个代码步骤均给出完整代码与确切命令/期望输出；无 “TODO/TBD/类似上文” 占位。`EpisodeViewPlaceholder` 是产品占位屏（有意为之、已在 Architecture 与 Task 6 Step 3 标注后续计划替换），非计划占位。✓

**3. Type consistency：** `EpisodeView{canvas,storyboard,script,generation,queue}`、`currentEpisodeViewProvider`、`EpisodeViewNav`、`EpisodeViewNav.tabKey(view)`、`EpisodeViewPlaceholder({required view})`、l10n getter `episodeView*` / `episodeViewComingSoon(String)` 在各任务间命名一致。✓

**已知偏差（非阻塞）：** mockup 中 `.view-nav` 在 logo 与 crumbs 之后**左对齐**，而 `InkWindowChrome.center` 居中——本计划把 `Row[Breadcrumb, EpisodeViewNav]` 放进既有 center 槽（与 `StudioTopChrome` 居中 breadcrumb 的现状一致），不改 `InkWindowChrome` 的三槽模型以免波及 Studio/Settings 三屏。若后续要求严格左对齐，应另起一个「chrome 槽模型重构」计划。
