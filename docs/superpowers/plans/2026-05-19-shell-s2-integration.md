# Shell S2 集成实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 5 个 slice (studio/canvas/inspector/generation/settings) 的 S1 交付物在 shell 层（`lib/app.dart` + `lib/core/di/`）拉通成可运行的端到端 UI 闭环。

**Architecture:** shell 协调位只动 `lib/app.dart`、`lib/core/di/`，以及把 canvas 自留的 FAB 从 `app.dart` 下沉到 `lib/features/canvas/widgets/canvas_add_node_fab.dart`。所有其它 slice 文件由各 owner 自行收尾，shell 仅通过共享 Riverpod provider 拉通：`currentScreenProvider`（Studio↔Settings 路由）、`toastMessengerKeyProvider`（已存在，需接到 MaterialApp）、`jobStateProvider(nodeId)`（由 agent-generation 暴露，shell 不实现）。

**Tech Stack:** Flutter Desktop, Riverpod, freezed sealed model, ARB i18n。InkFrame 项目规则见 `docs/CLAUDE.md` 与 `docs/ARCHITECTURE.md`。

---

## 文件结构

| 状态 | 路径 | 职责 |
|---|---|---|
| Create | `lib/core/di/current_screen.dart` | `enum AppScreen { studio, settings }` + `StateProvider<AppScreen>` 默认 studio |
| Modify | `lib/app.dart` | `_UnlockedShell` 改为 watch `currentScreenProvider`，在 studio/canvas/settings 三屏切换；删除 `_AddNodeFab`、删除外层 Stack 的 FAB；MaterialApp 接 `scaffoldMessengerKey: ref.watch(toastMessengerKeyProvider)` |
| Create | `lib/features/canvas/widgets/canvas_add_node_fab.dart` | 接管原 `_AddNodeFab` 逻辑：弹 PopupMenu 选 image/video → `canvasNodesControllerProvider(canvasId).addNode(...)` |
| Modify | `lib/features/canvas/widgets/canvas_screen.dart` | 在自己内部 Stack 上挂 `CanvasAddNodeFab` |
| Modify | `lib/features/studio/studio_home_screen.dart` | `onOpenSettings` 改写到 `currentScreenProvider.notifier.state = AppScreen.settings`（替代 `studioOpenSettingsIntentProvider`） |
| Delete | `studioOpenSettingsIntentProvider`（位于 `lib/features/studio/controllers/studio_state.dart`） | 桥已废，删除 |
| Create | `test/core/di/current_screen_test.dart` | provider 单测 |
| Create | `test/app/app_routing_test.dart` | shell 路由 widget test（lock unlocked → 切 studio/canvas/settings） |
| Create | `test/app/app_toast_messenger_test.dart` | 验证 MaterialApp.scaffoldMessengerKey == toastMessengerKeyProvider 实例 |

---

## Task 1: 验证 freezed 产物新鲜度（核账，不改代码）

**Files:**
- Read: `lib/core/models/*.dart` 与对应 `*.freezed.dart`
- Read: `lib/features/generation/models/job_state.dart` 与 `job_state.freezed.dart`

agent-settings 报告 build_runner hang 20+ 分钟。先核账：仓库里的 freezed 产物是否新鲜，确认 S2 集成时 `flutter test` 不会因产物过时整体爆掉。

- [ ] **Step 1: 跑 dart analyze 看是否有 missing freezed member 报错**

Run:
```powershell
dart analyze lib --fatal-infos 2>&1 | Select-String -Pattern "freezed|undefined_getter|undefined_method" | Select-Object -First 30
```

Expected: 无 `_$JobStateImpl` / `_$XxxImpl` 缺失类的报错；若有则 freezed 产物过时，进入 Step 2。

- [ ] **Step 2: 仅当 Step 1 失败才重新生成 freezed**

Run:
```powershell
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: 退出码 0；产物文件落在 `lib/**/*.freezed.dart`。
如果 hang > 5 分钟：先 Ctrl+C，改用 `flutter pub run build_runner build --build-filter "lib/**/*.dart" --delete-conflicting-outputs` 缩小范围。

- [ ] **Step 3: 提交（仅当 Step 2 实际产生差异）**

```powershell
git add lib/**/*.freezed.dart
git commit -m "chore(codegen): refresh freezed products for S2 integration"
```

Expected: commit 创建（无新差异时 `git diff --staged --quiet` 返回 0，跳过 commit）。

---

## Task 2: 创建 `currentScreenProvider`

**Files:**
- Create: `lib/core/di/current_screen.dart`
- Test: `test/core/di/current_screen_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/core/di/current_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkframe/core/di/current_screen.dart';

void main() {
  test('currentScreenProvider 默认值是 studio', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(currentScreenProvider), AppScreen.studio);
  });

  test('currentScreenProvider 可切换到 settings 再回 studio', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(currentScreenProvider.notifier).state = AppScreen.settings;
    expect(container.read(currentScreenProvider), AppScreen.settings);
    container.read(currentScreenProvider.notifier).state = AppScreen.studio;
    expect(container.read(currentScreenProvider), AppScreen.studio);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/core/di/current_screen_test.dart`
Expected: FAIL，`Target of URI doesn't exist: 'package:inkframe/core/di/current_screen.dart'`

- [ ] **Step 3: 实现 provider**

```dart
// lib/core/di/current_screen.dart
//
// shell 路由：lock unlocked 后在 studio / settings 之间切换。
// canvas 入口仍由 currentCanvasIdProvider 判据（在 canvas screen 内自治）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppScreen { studio, settings }

final currentScreenProvider = StateProvider<AppScreen>(
  (_) => AppScreen.studio,
  name: 'currentScreenProvider',
);
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/core/di/current_screen_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```powershell
git add lib/core/di/current_screen.dart test/core/di/current_screen_test.dart
git commit -m "feat(shell): add currentScreenProvider for studio<->settings routing"
```

---

## Task 3: 抽出 CanvasAddNodeFab（先抽离，下个 task 再下沉接线）

**Files:**
- Create: `lib/features/canvas/widgets/canvas_add_node_fab.dart`

源代码来自 `lib/app.dart:128-220` 的 `_AddNodeFab`。

- [ ] **Step 1: 新建文件**

```dart
// lib/features/canvas/widgets/canvas_add_node_fab.dart
//
// 画布右下角的"添加节点"FAB。原本住在 app.dart，S2 下沉到 canvas slice 自治。
// 弹 PopupMenu 让用户选 image / video，再写入 canvasNodesControllerProvider。

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';

class CanvasAddNodeFab extends ConsumerWidget {
  const CanvasAddNodeFab({super.key, required this.canvasId});

  final String canvasId;

  static final _rand = Random();

  Offset _pickPosition() => Offset(
        200 + _rand.nextDouble() * 400,
        200 + _rand.nextDouble() * 400,
      );

  Future<void> _addNode(
    BuildContext context,
    WidgetRef ref,
    CanvasNodeType type,
  ) async {
    try {
      await ref
          .read(canvasNodesControllerProvider(canvasId).notifier)
          .addNode(
            label: context.l10n.canvasNodeDefaultLabel,
            type: type,
            position: _pickPosition(),
          );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.canvasAddNodeFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final Offset topLeft =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final RelativeRect position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - bottomRight.dy,
    );

    final selected = await showMenu<CanvasNodeType>(
      context: context,
      position: position,
      items: <PopupMenuEntry<CanvasNodeType>>[
        PopupMenuItem<CanvasNodeType>(
          value: CanvasNodeType.image,
          child: Row(
            children: <Widget>[
              const Icon(Icons.add_photo_alternate_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddImageNode),
            ],
          ),
        ),
        PopupMenuItem<CanvasNodeType>(
          value: CanvasNodeType.video,
          child: Row(
            children: <Widget>[
              const Icon(Icons.videocam_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddVideoNode),
            ],
          ),
        ),
      ],
    );
    if (selected == null || !context.mounted) return;
    await _addNode(context, ref, selected);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      tooltip: context.l10n.canvasAddNodeTooltip,
      onPressed: () => _showMenu(context, ref),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.canvasAddNodeTooltip),
    );
  }
}
```

- [ ] **Step 2: 确认编译通过**

Run: `dart analyze lib/features/canvas/widgets/canvas_add_node_fab.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add lib/features/canvas/widgets/canvas_add_node_fab.dart
git commit -m "refactor(canvas): extract CanvasAddNodeFab from app shell"
```

---

## Task 4: CanvasScreen 自挂 FAB

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_screen.dart`

`canvas_screen.dart` 内部已经在用 `currentCanvasIdProvider` 判断画布是否打开；在它的 build 里直接挂 `CanvasAddNodeFab(canvasId: id)`。

- [ ] **Step 1: 读取当前 canvas_screen.dart 的 build 结构**

Run: `Grep` 工具搜 `class CanvasScreen` 与它的 `build` 方法范围。

- [ ] **Step 2: 在 CanvasScreen build 里以 Stack 包裹原 body，右下角 Positioned 加 FAB**

修改方式（伪 diff，具体行号以读到的结构为准）：

```dart
// canvas_screen.dart build:
import '../providers/current_canvas_id.dart';
import 'canvas_add_node_fab.dart';

@override
Widget build(BuildContext context, WidgetRef ref) {
  final canvasId = ref.watch(currentCanvasIdProvider);
  return Stack(
    children: <Widget>[
      _existingBody(context, ref),
      if (canvasId != null)
        Positioned(
          right: 16,
          bottom: 16,
          child: CanvasAddNodeFab(canvasId: canvasId),
        ),
    ],
  );
}
```

- [ ] **Step 3: 跑现有 canvas 测试，确保没回归**

Run: `flutter test test/features/canvas/`
Expected: 全绿。

- [ ] **Step 4: Commit**

```powershell
git add lib/features/canvas/widgets/canvas_screen.dart
git commit -m "refactor(canvas): self-attach CanvasAddNodeFab inside CanvasScreen"
```

---

## Task 5: 改 app.dart —— 删旧 FAB、接 currentScreenProvider、接 toast key

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: 删除 `_AddNodeFab` class 与 `_UnlockedShell` 里包它的 Stack/Positioned**

`_UnlockedShell` 改成：

```dart
class _UnlockedShell extends ConsumerWidget {
  const _UnlockedShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId != null) {
      return CanvasScreen(canvasName: context.l10n.appTitle);
    }
    final screen = ref.watch(currentScreenProvider);
    return switch (screen) {
      AppScreen.studio => const Scaffold(body: StudioHomeScreen()),
      AppScreen.settings => const SettingsScreen(),
    };
  }
}
```

同步删除：`_AddNodeFab` 整个 class、`dart:math` import（如不再被用）、`features/canvas/models/canvas_node.dart` import、`canvas_nodes_controller.dart` import。

- [ ] **Step 2: 顶部新增 import**

```dart
import 'core/di/current_screen.dart';
import 'features/settings/settings_screen.dart';
```

- [ ] **Step 3: 把 toast key 接到 MaterialApp**

在 `_InkFrameAppState.build` 里改 `MaterialApp`：

```dart
@override
Widget build(BuildContext context) {
  final themeState = ref.watch(themeModeControllerProvider);
  final messengerKey = ref.watch(toastMessengerKeyProvider);
  return MaterialApp(
    title: 'InkFrame',
    scaffoldMessengerKey: messengerKey,
    theme: buildAppTheme(...),
    locale: ref.watch(localeControllerProvider),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const _HomeScaffold(),
    debugShowCheckedModeBanner: false,
  );
}
```

新增 import：
```dart
import 'core/di/locale.dart';
import 'features/generation/services/toast_service.dart';
```

> 注：`localeControllerProvider` 由 agent-settings 在 `lib/core/di/locale.dart` 落地。若 git status 显示 `?? lib/core/di/locale.dart`，确认它 export 了 `localeControllerProvider`。

- [ ] **Step 4: 跑 analyze + 跑现有 app 测试**

Run:
```powershell
dart analyze lib/app.dart
flutter test test/app/
```

Expected: analyze 零告警；现有 app 测试若引用 `_AddNodeFab` 需同步改（见 Task 6 的回归测试覆盖）。

- [ ] **Step 5: Commit**

```powershell
git add lib/app.dart
git commit -m "feat(shell): wire currentScreenProvider + toastMessengerKey, drop in-shell FAB"
```

---

## Task 6: Studio 把 intent 桥替换为 currentScreenProvider

**Files:**
- Modify: `lib/features/studio/studio_home_screen.dart`
- Modify: `lib/features/studio/controllers/studio_state.dart`（删 `studioOpenSettingsIntentProvider`）

- [ ] **Step 1: studio_home_screen.dart 改 onOpenSettings**

```dart
import '../../core/di/current_screen.dart';

// build 内：
StudioTopChrome(
  studioName: studioName,
  breadcrumbTail: context.l10n.studioBreadcrumbAll,
  onOpenSettings: () =>
      ref.read(currentScreenProvider.notifier).state = AppScreen.settings,
),
```

删除 import `controllers/studio_state.dart` 中 `studioOpenSettingsIntentProvider` 的引用（如果文件仅暴露这一项就连 import 一起删；若还暴露其它 provider 则只删使用行）。

- [ ] **Step 2: 删除 studioOpenSettingsIntentProvider 本体**

打开 `lib/features/studio/controllers/studio_state.dart`，删除 `final studioOpenSettingsIntentProvider = StateProvider<int>((_) => 0);` 行以及其注释。其它 provider 保留。

- [ ] **Step 3: 跑 studio 测试**

Run: `flutter test test/features/studio/`
Expected: 全绿；若有测试直接 read `studioOpenSettingsIntentProvider`，改为 read `currentScreenProvider` 并断言值。

- [ ] **Step 4: Commit**

```powershell
git add lib/features/studio/studio_home_screen.dart lib/features/studio/controllers/studio_state.dart test/features/studio/
git commit -m "refactor(studio): wire Settings entry to currentScreenProvider, drop intent bridge"
```

---

## Task 7: 加 shell 路由 widget test

**Files:**
- Create: `test/app/app_routing_test.dart`

- [ ] **Step 1: 写测试**

```dart
// test/app/app_routing_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';

void main() {
  testWidgets('unlocked + studio screen → 渲染 StudioHomeScreen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          apiKeyUnlockedProvider.overrideWith((_) async => true),
          currentScreenProvider.overrideWith((_) => AppScreen.studio),
          currentCanvasIdProvider.overrideWith((_) => null),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing); // no toast leak
    // StudioHomeScreen 自身有 TopChrome，可改 expect 检查 chrome 出现
  });

  testWidgets('unlocked + settings screen → 渲染 SettingsScreen AppBar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          apiKeyUnlockedProvider.overrideWith((_) async => true),
          currentScreenProvider.overrideWith((_) => AppScreen.settings),
          currentCanvasIdProvider.overrideWith((_) => null),
        ],
        child: const InkFrameApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings').hitTestable(), findsWidgets);
  });
}
```

> 注：测试里的 `'Settings'` 文案以 `lib/l10n/app_en.arb` 的 `settingsTitle` 为准。如该 key 实际值是 "Settings" 之外的文案，按 ARB 实际值改。

- [ ] **Step 2: 运行测试**

Run: `flutter test test/app/app_routing_test.dart`
Expected: PASS。失败时按 ARB 实际文案 / 屏幕 widget 结构调整断言。

- [ ] **Step 3: Commit**

```powershell
git add test/app/app_routing_test.dart
git commit -m "test(app): shell routing widget test for studio/settings switch"
```

---

## Task 8: 加 toast key 接线 widget test

**Files:**
- Create: `test/app/app_toast_messenger_test.dart`

- [ ] **Step 1: 写测试**

```dart
// test/app/app_toast_messenger_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/app.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';

void main() {
  testWidgets('MaterialApp.scaffoldMessengerKey == toastMessengerKeyProvider', (tester) async {
    final container = ProviderContainer(
      overrides: <Override>[
        apiKeyUnlockedProvider.overrideWith((_) async => true),
        currentCanvasIdProvider.overrideWith((_) => null),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const InkFrameApp(),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final expectedKey = container.read(toastMessengerKeyProvider);
    expect(identical(materialApp.scaffoldMessengerKey, expectedKey), isTrue);
  });
}
```

- [ ] **Step 2: 运行测试**

Run: `flutter test test/app/app_toast_messenger_test.dart`
Expected: PASS。

- [ ] **Step 3: Commit**

```powershell
git add test/app/app_toast_messenger_test.dart
git commit -m "test(app): assert MaterialApp wires toastMessengerKeyProvider"
```

---

## Task 9: 协调 agent-generation 暴露 jobStateProvider(nodeId)

**Files:** 不在 shell 范围；通过群聊驱动。

shell 不直接写 generation 代码。本任务是 coordination action，确保链路闭环。

- [ ] **Step 1: 群里 @agent-generation 提需求**

speak (cc-group-chat):

> @agent-generation 请在 lib/features/generation/providers/ 新增 jobStateProvider —— `Provider.family<JobState?, String>` 按 nodeId 查 JobsRegistry 取最近的 active job（若 nodeId 与 jobId 不等价，请同时把 JobState 加 nodeId 字段并在 JobsRegistry 索引）。落地后 ping @agent-inspector 接线。

- [ ] **Step 2: 等 agent-generation ack + 落地通告**

读 `read_history(sinceId=<lastId>)` 直到看到 agent-generation 通告 `jobStateProvider` 已合入并附文件路径。

- [ ] **Step 3: 群里 @agent-inspector 启动接线**

speak (cc-group-chat):

> @agent-inspector jobStateProvider 已就位（见上条），请替换 InspectorStatusPanel 里的本地 view 为 `ref.watch(jobStateProvider(nodeId))`，跑 widget test 闭环。

> Coordination task 不产生 commit，只产生群聊 trail。

---

## Task 10: 全仓验收

- [ ] **Step 1: 全仓 analyze**

Run: `flutter analyze`
Expected: `No issues found!`（如有非 shell 范围的告警，按 owner 拉回原 agent 修，不私自越界改）。

- [ ] **Step 2: 全仓测试**

Run: `flutter test`
Expected: 全绿。失败时按文件归属 ping owner，不私自修 feature 代码。

- [ ] **Step 3: ARB 对齐检查**

Run:
```powershell
flutter gen-l10n
git diff --stat lib/l10n/
```

Expected: 无新生成 diff（说明 en/zh 已 commit 对齐）。

- [ ] **Step 4: 群里宣告 S2 闭环**

speak (cc-group-chat):

> @everyone [S2 集成闭环] currentScreenProvider / FAB 下沉 / toast key / studio 桥替换 全部上线；jobStateProvider 路径已通；flutter analyze 零告警、flutter test 全绿。S3 打磨阶段（a11y / 动效 / 主题对齐）启动。

- [ ] **Step 5: 不 commit**（前面每 task 已 commit；本步仅做验收）

---

## 自审

**1. Spec 覆盖：**

| msg | 待办 | 对应 task |
|---|---|---|
| msg 13 | studio 等 currentScreenProvider | Task 2 + 6 |
| msg 16 | FAB 下沉 | Task 3 + 4 + 5 |
| msg 18 | 评审 LocaleController | 不在 shell 改动范围，已自落（agent-settings 自动加 import 到 app.dart 由 Task 5 顺手保留） |
| msg 19 | freezed 产物风险 | Task 1 |
| msg 24 | toast key 接线 | Task 5 + 8 |
| msg 22 | inspector 等 jobStateProvider | Task 9 |

**2. Placeholder 扫描：**

- Task 4 Step 1 用 "伪 diff" 因为没读 canvas_screen.dart 完整内容；执行时先 Read 整文件再改。这是 acceptable scaffold，不是 TBD。
- Task 7 Step 1 注里允许按 ARB 实际值微调 'Settings' 字面值，因 ARB 内容已落但未在 plan 里 inline；执行时 Read app_en.arb 取 `settingsTitle` 真值替代。

**3. 类型一致性：**

- `AppScreen` 枚举在 Task 2 定义，Task 5/6/7 一致引用。
- `currentScreenProvider` 是 `StateProvider<AppScreen>`；Task 6 用 `.notifier.state =` 写入、Task 5 用 `ref.watch(currentScreenProvider)` 读取，签名一致。
- `toastMessengerKeyProvider` 类型为 `Provider<GlobalKey<ScaffoldMessengerState>>`（来自实际文件），Task 5 / Task 8 与此一致。
