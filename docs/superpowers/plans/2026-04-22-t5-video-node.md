# T5 Sprint — 视频节点 UI 接入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把已注册的 5 款视频 Provider（wanx-t2v/i2v/r2v + kling-v3/v3-omni）真正 user-visible —— 用户在 canvas 上建 video 节点、跑视频生成、在灯箱里播放。

**Architecture:** 复用 T4 的 canvas + Inspector + GenerationController 主干，新增 3 条插件式服务（VideoDownloadService / ThumbnailService / VideoPlayerService），均抽 abstract interface + Riverpod DI，media_kit 作为底层视频库（ADR-0006 决策）。Schema 不动 —— `nodes.type` 枚举已含 `'video'`，`type_config` JSONB 新增 `video_url / thumbnail_url / duration_ms / camera / mode` 键。JobQueueService 补 `_persistRemoteUrls` 通道（现有版本只处理 `inlineBytes`），dio 下载 + media_kit 抽首帧。

**Tech Stack:** Flutter Desktop / Riverpod / media_kit + media_kit_video + media_kit_libs_video / dio / freezed

**Spec 关联:** `docs/specs/2026-04-22-t5-direction-candidates.md` 候选 C / PRD §5 视频节点 / PRD §4.6 mode 推断 / §4.5 result 节点 / §10.3 生成流程 / §12.6 FileResolver 相对路径

**Sprint 规模:** 7 个 PR / 5-7 工作日 / 参考 T4 S1-S4 切片节奏

**范围明确排除（defer 到 T5.1 / T6）:**
- 提取帧功能（PRD §5.5）—— 需要任意时刻 frame seek，ffmpeg CLI 调用；T5 只做首帧缩略
- 批量视频（`batch_size > 1`）—— 当前 5 款 Provider 全部 `batch_size=1`
- 视频导出 / 剪辑（PRD §13）
- Hailuo Provider 注册（spec 提及但未在 registry 内；独立追加 PR）

**Sprint 切片一览:**
| Slice | 内容 | 触达文件数估计 |
|---|---|---|
| S0 | ADR-0006 视频库决策（docs） | 2 |
| S1 | pubspec 依赖 + CanvasNode video getters + Flutter plugin registrant | 7 |
| S2 | NodeInspectorRouter + VideoConfigInspector | 6 |
| S3 | VideoDownloadService + GenerationController video 分支 + JobQueue remoteUrls 通道 | 9 |
| S4 | ThumbnailService + NodeCard video body | 6 |
| S5 | VideoPlayerService + VideoLightbox | 5 |
| S6 | Add Video Node FAB 菜单 | 2 |
| S7 | Release v0.1.0-alpha.8 | 0（tag only） |

---

## File Structure

### 新建文件

| 路径 | 职责 |
|---|---|
| `docs/adr/0006-video-playback-library.md` | 视频播放库决策记录 |
| `lib/features/canvas/widgets/node_inspector_router.dart` | 按 `node.type` 分流 Inspector |
| `lib/features/canvas/widgets/video_config_inspector.dart` | video 节点参数面板 |
| `lib/features/canvas/widgets/video_node_body.dart` | NodeCard 视频 result 分支 |
| `lib/features/canvas/widgets/video_lightbox.dart` | 全屏视频播放 Dialog |
| `lib/core/interfaces/video_download_service.dart` | VideoDownloadService 接口 |
| `lib/core/interfaces/thumbnail_service.dart` | ThumbnailService 接口 |
| `lib/core/interfaces/video_player_service.dart` | VideoPlayerService 接口 |
| `lib/services/dio_video_download_service.dart` | dio 实现 |
| `lib/services/media_kit_thumbnail_service.dart` | media_kit 抽首帧实现 |
| `lib/services/media_kit_video_player_service.dart` | media_kit 播放实现 |
| `lib/core/di/video_download.dart` | Riverpod provider |
| `lib/core/di/thumbnail.dart` | Riverpod provider |
| `lib/core/di/video_player.dart` | Riverpod provider |
| `docs/internal/t5-manual-regression.md` | 手动回归清单 |
| 单测若干（见各 slice） | |

### 修改文件

| 路径 | 改什么 |
|---|---|
| `pubspec.yaml` | 加 `media_kit` / `media_kit_video` / `media_kit_libs_video` |
| `pubspec.lock` | pub get 自动更新 |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | flutter pub get 自动注册 media_kit 平台插件 |
| `windows/flutter/generated_plugin_registrant.cc` | 同上 Windows |
| `windows/flutter/generated_plugins.cmake` | 同上 Windows build |
| `lib/features/canvas/models/canvas_node.dart` | 加 `videoUrl` / `thumbnailUrl` / `durationMs` / `cameraName` / `videoMode` getters |
| `lib/features/canvas/widgets/node_card.dart` | `_ResultBody` 分 image/video 两支 |
| `lib/features/canvas/widgets/canvas_view.dart` | Inspector 走 router，video result tap → lightbox |
| `lib/features/canvas/widgets/config_node_inspector.dart` | 重命名为 `image_config_inspector.dart`（class 也跟着改） |
| `lib/features/generation/generation_controller.dart` | 按 `cfgRow.type` 分支：image / video；task.mode / durationSeconds / camera |
| `lib/services/job_queue_service.dart` | 新增 `_persistRemoteUrls`：下载 → videos/ + thumbnail 抽帧 + patchTypeConfig |
| `lib/core/di/job_queue.dart` | wire downloader + thumbnail providers |
| `lib/main.dart` | `MediaKit.ensureInitialized()` |
| `lib/app.dart` | `_AddNodeFab` 扩展为菜单（image / video） |
| `lib/l10n/app_en.arb` | 新增约 18 个 key |
| `lib/l10n/app_zh.arb` | 同上 zh 翻译 |
| `docs/PROVIDER-API.md` | 补 `remoteUrls` 下载约定段落 |
| `docs/BUILD-RELEASE.md` | 补 media_kit 平台依赖（macOS / Windows libmpv） |
| `docs/adr/0000-index.md` | 追加 ADR-0006 行 |
| `docs/specs/2026-04-22-t5-direction-candidates.md` | 修正 "6 款" → "5 款" + T5 收口记录 |

---

## Slice 0 — ADR-0006 视频播放库决策

**分支：** `docs/adr-0006-video-playback-library`
**PR 标题：** `docs(adr): 0006 video playback library — media_kit`

### Task 0.1: 起草 ADR-0006

**Files:**
- Create: `docs/adr/0006-video-playback-library.md`
- Modify: `docs/adr/0000-index.md`

- [ ] **Step 1: 起草 ADR（参照 ADR-0004 / 0005 风格：Context / Decision / Consequences / Alternatives / Revisit Triggers / 影响文件）**

- [ ] **Step 2: 更新 ADR index**

先 Read `docs/adr/0000-index.md`，确认表格格式。现有格式为：
```
| [ADR-NNNN](NNNN-slug.md) | 标题 | accepted | YYYY-MM-DD |
```

追加一行：
```markdown
| [ADR-0006](0006-video-playback-library.md) | 视频播放库：media_kit | accepted | 2026-04-22 |
```

- [ ] **Step 3: Commit + push + PR**

```bash
git checkout -b docs/adr-0006-video-playback-library
git add docs/adr/0006-video-playback-library.md docs/adr/0000-index.md
git commit -m "docs(adr): 0006 video playback library — media_kit"
git push -u origin docs/adr-0006-video-playback-library
gh pr create --base dev --title "docs(adr): 0006 video playback library — media_kit" --body "T5 Sprint 前置决策：media_kit 作为唯一横跨 macOS + Windows 的活跃方案。"
```

---

## Slice 1 — pubspec 依赖 + CanvasNode video getters + Plugin Registrant

**分支：** `feature/t5-s1-video-model-prep`
**PR 标题：** `feat(models): CanvasNode video getters + media_kit deps (T5-S1)`

### Task 1.1: 加依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 加依赖**

Edit `pubspec.yaml` under `dependencies:`, append before `dev_dependencies:`:

```yaml
  # T5：视频播放 + 首帧抽帧
  media_kit: ^1.1.11
  media_kit_video: ^1.2.5
  media_kit_libs_video: ^1.0.5
```

- [ ] **Step 2: flutter pub get**

```bash
flutter pub get
```

Expected: `Got dependencies!` + 三个 media_kit 包在 `flutter pub deps` 里 resolved。

- [ ] **Step 3: 确认 Flutter 自动生成的平台 plugin registrant 被 git 发现**

Expected 修改（flutter pub get 自动产出，必须 commit）：
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugins.cmake`

若少了其中任何一个，意味着 plugin 未注册 —— `flutter run` 时 `MediaKit.ensureInitialized()` 会报缺符号。把这 3 个文件加进本 commit。

### Task 1.2: CanvasNode video getters（TDD）

**Files:**
- Test: `test/features/canvas/models/canvas_node_video_test.dart`
- Modify: `lib/features/canvas/models/canvas_node.dart`

- [ ] **Step 1: 写失败测试**

Create `test/features/canvas/models/canvas_node_video_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  group('CanvasNode video getters', () {
    test('videoUrl 返回 type_config.video_url', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        typeConfig: {'video_url': 'videos/job-1.mp4'},
      );
      expect(node.videoUrl, 'videos/job-1.mp4');
    });

    test('videoUrl 缺失返回 null', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.result,
      );
      expect(node.videoUrl, isNull);
    });

    test('thumbnailUrl 返回 type_config.thumbnail_url', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        typeConfig: {'thumbnail_url': 'videos/job-1.jpg'},
      );
      expect(node.thumbnailUrl, 'videos/job-1.jpg');
    });

    test('durationMs / camera / mode 读 type_config', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.config,
        typeConfig: {
          'duration_ms': 5000,
          'camera': 'pushIn',
          'mode': 't2v',
        },
      );
      expect(node.durationMs, 5000);
      expect(node.cameraName, 'pushIn');
      expect(node.videoMode, 't2v');
    });

    test('videoMode 缺失返回 null', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.config,
      );
      expect(node.videoMode, isNull);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/features/canvas/models/canvas_node_video_test.dart
```

Expected: FAIL — `The getter 'videoUrl' isn't defined`

- [ ] **Step 3: 加 getters**

在 `lib/features/canvas/models/canvas_node.dart` 的 `imageUrl` getter 下追加：

```dart
  /// video result 节点的相对视频路径；非 video 或未设置时为 null。
  String? get videoUrl {
    final v = typeConfig['video_url'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// video result 节点的首帧缩略图相对路径；未抽帧时为 null。
  String? get thumbnailUrl {
    final v = typeConfig['thumbnail_url'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// video config 节点的时长（毫秒）；未设置返回 null。
  int? get durationMs {
    final v = typeConfig['duration_ms'];
    return v is int ? v : null;
  }

  /// video config 节点的运镜名（CameraMovement.name）；未设置返回 null。
  String? get cameraName {
    final v = typeConfig['camera'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// video config 节点的生成模式（"t2v" / "i2v"）；未设置返回 null，
  /// 生成时按 incoming data edges 自动推断（见 GenerationController）。
  String? get videoMode {
    final v = typeConfig['mode'];
    return v is String && v.isNotEmpty ? v : null;
  }
```

- [ ] **Step 4: 跑测试确认通过**

```bash
flutter test test/features/canvas/models/canvas_node_video_test.dart
```

Expected: PASS — 5 tests.

- [ ] **Step 5: Commit + PR**

```bash
git checkout -b feature/t5-s1-video-model-prep
git add pubspec.yaml pubspec.lock \
       lib/features/canvas/models/canvas_node.dart \
       test/features/canvas/models/canvas_node_video_test.dart \
       macos/Flutter/GeneratedPluginRegistrant.swift \
       windows/flutter/generated_plugin_registrant.cc \
       windows/flutter/generated_plugins.cmake
git commit -m "feat(models): CanvasNode video getters + media_kit deps (T5-S1)"
git push -u origin feature/t5-s1-video-model-prep
gh pr create --base dev --title "feat(models): CanvasNode video getters + media_kit deps (T5-S1)" --body "T5 Sprint 起手：pubspec 加 media_kit + CanvasNode 加 video/thumbnail/duration/camera/mode getters + macOS/Windows plugin registrant（flutter pub get 自动产出，不 commit 会导致 plugin 不注册）。纯模型层改动，无运行时依赖。"
```

---

## Slice 2 — NodeInspectorRouter + VideoConfigInspector

**分支：** `feature/t5-s2-video-inspector`
**PR 标题：** `feat(canvas): VideoConfigInspector + NodeInspectorRouter (T5-S2)`

### Task 2.1: 重命名 config_node_inspector → image_config_inspector

**Files:**
- Rename: `lib/features/canvas/widgets/config_node_inspector.dart` → `lib/features/canvas/widgets/image_config_inspector.dart`
- Modify: import 站点（grep 定位）

- [ ] **Step 1: git mv**

```bash
git mv lib/features/canvas/widgets/config_node_inspector.dart \
       lib/features/canvas/widgets/image_config_inspector.dart
```

- [ ] **Step 2: class 重命名**
- `class ConfigNodeInspector` → `class ImageConfigInspector`
- `_ConfigNodeInspectorState` → `_ImageConfigInspectorState`

- [ ] **Step 3: 修 import 站点**

```bash
grep -rn "ConfigNodeInspector\|config_node_inspector" lib/ test/
```

对每个 hit：改 import 路径 + class 名。

- [ ] **Step 4: 编译 smoke**

```bash
flutter analyze lib/
```

Expected: `No issues found!`

### Task 2.2: NodeInspectorRouter 骨架

**Files:**
- Create: `lib/features/canvas/widgets/node_inspector_router.dart`
- Create: `lib/features/canvas/widgets/video_config_inspector.dart`（骨架）
- Test: `test/features/canvas/widgets/node_inspector_router_test.dart`

- [ ] **Step 1: 写 router widget test**

Create `test/features/canvas/widgets/node_inspector_router_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/image_config_inspector.dart';
import 'package:inkframe/features/canvas/widgets/node_inspector_router.dart';
import 'package:inkframe/features/canvas/widgets/video_config_inspector.dart';
import 'package:inkframe/l10n/app_localizations.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('image 节点 → ImageConfigInspector', (tester) async {
    const node = CanvasNode(
      id: 'n1', label: '', type: CanvasNodeType.image, role: NodeRole.config,
    );
    await tester.pumpWidget(_host(const NodeInspectorRouter(node: node)));
    expect(find.byType(ImageConfigInspector), findsOneWidget);
    expect(find.byType(VideoConfigInspector), findsNothing);
  });

  testWidgets('video 节点 → VideoConfigInspector', (tester) async {
    const node = CanvasNode(
      id: 'n1', label: '', type: CanvasNodeType.video, role: NodeRole.config,
    );
    await tester.pumpWidget(_host(const NodeInspectorRouter(node: node)));
    expect(find.byType(VideoConfigInspector), findsOneWidget);
    expect(find.byType(ImageConfigInspector), findsNothing);
  });

  testWidgets('result 节点不渲染 Inspector', (tester) async {
    const node = CanvasNode(
      id: 'n1', label: '', type: CanvasNodeType.image,
      role: NodeRole.result, sourceNodeId: 's1',
    );
    await tester.pumpWidget(_host(const NodeInspectorRouter(node: node)));
    expect(find.byType(ImageConfigInspector), findsNothing);
    expect(find.byType(VideoConfigInspector), findsNothing);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/features/canvas/widgets/node_inspector_router_test.dart
```

Expected: FAIL — `NodeInspectorRouter` / `VideoConfigInspector` 未定义。

- [ ] **Step 3: 写 router widget**

Create `lib/features/canvas/widgets/node_inspector_router.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/canvas_node.dart';
import 'image_config_inspector.dart';
import 'video_config_inspector.dart';

class NodeInspectorRouter extends StatelessWidget {
  const NodeInspectorRouter({super.key, required this.node});
  final CanvasNode node;

  @override
  Widget build(BuildContext context) {
    if (node.role != NodeRole.config) return const SizedBox.shrink();
    return switch (node.type) {
      CanvasNodeType.image => ImageConfigInspector(node: node),
      CanvasNodeType.video => VideoConfigInspector(node: node),
      CanvasNodeType.text || CanvasNodeType.shot => const SizedBox.shrink(),
    };
  }
}
```

- [ ] **Step 4: 占位 VideoConfigInspector**

Create `lib/features/canvas/widgets/video_config_inspector.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/canvas_node.dart';

class VideoConfigInspector extends ConsumerStatefulWidget {
  const VideoConfigInspector({super.key, required this.node});
  final CanvasNode node;

  @override
  ConsumerState<VideoConfigInspector> createState() =>
      _VideoConfigInspectorState();
}

class _VideoConfigInspectorState extends ConsumerState<VideoConfigInspector> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 320);
  }
}
```

- [ ] **Step 5: 跑测试确认通过**

```bash
flutter test test/features/canvas/widgets/node_inspector_router_test.dart
```

Expected: PASS — 3 tests.

### Task 2.3: canvas_view 改走 router

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_view.dart`

- [ ] **Step 1: 替换 Inspector 站点**

`ImageConfigInspector(node: <x>)` → `NodeInspectorRouter(node: <x>)`，import 相应改。

- [ ] **Step 2: 编译 + 现有测试不破**

```bash
flutter analyze lib/
flutter test test/features/canvas/
```

### Task 2.4: VideoConfigInspector — 实现 prompt + provider + duration + camera + autosave + Generate

**Files:**
- Test: `test/features/canvas/widgets/video_config_inspector_test.dart`
- Modify: `lib/features/canvas/widgets/video_config_inspector.dart`
- Modify: `lib/l10n/app_en.arb`, `app_zh.arb`

- [ ] **Step 1: i18n keys**

`app_en.arb` 追加（与 `app_zh.arb` 同步）：

```json
  "inspectorVideoPromptLabel": "Video prompt",
  "inspectorVideoDurationLabel": "Duration (seconds)",
  "inspectorVideoCameraLabel": "Camera movement",
  "inspectorVideoModeAuto": "Mode: auto-detected from inputs",
  "inspectorVideoModeT2v": "Text-to-video",
  "inspectorVideoModeI2v": "Image-to-video",
  "inspectorVideoGenerateDisabledEmptyPrompt": "Prompt required",
  "inspectorVideoGenerateDisabledNoKey": "API key required in Settings",
  "inspectorVideoGenerate": "Generate video"
```

zh 翻译对应。跑 `flutter gen-l10n`。

- [ ] **Step 2: widget 测试**

Create `test/features/canvas/widgets/video_config_inspector_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/video_config_inspector.dart';
import 'package:inkframe/l10n/app_localizations.dart';

ProviderCapabilities _fakeVideoCaps({String id = 'wanx-t2v'}) =>
    ProviderCapabilities(
      providerId: id,
      region: ProviderRegion.cn,
      modes: const [GenerationMode.textToVideo, GenerationMode.imageToVideo],
      supportedRatios: const [AspectRatio.r16x9, AspectRatio.r1x1],
      supportedResolutions: const [Resolution.p720, Resolution.p1080],
      supportedDurations: const [5, 10],
      supportedCameras: const [CameraMovement.static_, CameraMovement.pushIn],
      maxBatchSize: 1,
      maxRefImages: 1,
      refImagesIncludeKeyframes: false,
      supportsFirstFrame: false,
      supportsLastFrame: false,
      supportsNegativePrompt: false,
      supportsSeed: false,
      supportsSound: false,
      supportsBatch: false,
      supportsCancellation: true,
      supportsPolling: true,
      costModel: const CostModel.flat(amount: 0.1),
      maxConcurrentJobs: 1,
      qps: 1,
      burst: 1,
    );

Widget _host(Widget child, List<ProviderCapabilities> caps) => ProviderScope(
      overrides: [providerCapabilitiesListProvider.overrideWithValue(caps)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('prompt / duration / camera 控件渲染', (tester) async {
    const node = CanvasNode(
      id: 'n1', label: '', type: CanvasNodeType.video, role: NodeRole.config,
    );
    await tester.pumpWidget(
      _host(const VideoConfigInspector(node: node), [_fakeVideoCaps()]),
    );
    expect(find.text('视频提示词'), findsOneWidget);
    expect(find.text('时长（秒）'), findsOneWidget);
    expect(find.text('运镜'), findsOneWidget);
  });

  testWidgets('Generate 按钮初始 disabled（prompt 空）', (tester) async {
    const node = CanvasNode(
      id: 'n1', label: '', type: CanvasNodeType.video, role: NodeRole.config,
    );
    await tester.pumpWidget(
      _host(const VideoConfigInspector(node: node), [_fakeVideoCaps()]),
    );
    final btn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull);
  });
}
```

- [ ] **Step 3: 实现 VideoConfigInspector**

Replace `lib/features/canvas/widgets/video_config_inspector.dart` with：

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/repositories.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../features/generation/generation_controller.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';

class VideoConfigInspector extends ConsumerStatefulWidget {
  const VideoConfigInspector({super.key, required this.node});
  final CanvasNode node;

  @override
  ConsumerState<VideoConfigInspector> createState() =>
      _VideoConfigInspectorState();
}

class _VideoConfigInspectorState extends ConsumerState<VideoConfigInspector> {
  final TextEditingController _promptCtrl = TextEditingController();
  String? _providerId;
  int? _durationSec;
  CameraMovement? _camera;
  bool _running = false;
  Timer? _promptDebounce;
  static const _debounce = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    final caps = _videoCaps();
    final tc = widget.node.typeConfig;

    final savedProviderId = tc['provider_id'] as String?;
    _providerId =
        savedProviderId ?? (caps.isNotEmpty ? caps.first.providerId : null);
    final sel = _selectedCaps(caps);
    final savedDurMs = tc['duration_ms'];
    _durationSec = savedDurMs is int
        ? savedDurMs ~/ 1000
        : (sel?.supportedDurations.isNotEmpty == true
            ? sel!.supportedDurations.first
            : null);
    _camera = _parseCamera(tc['camera'] as String?) ??
        (sel?.supportedCameras.isNotEmpty == true
            ? sel!.supportedCameras.first
            : null);
    final savedPrompt = tc['prompt'];
    if (savedPrompt is String) _promptCtrl.text = savedPrompt;
  }

  @override
  void dispose() {
    _promptDebounce?.cancel();
    _promptCtrl.dispose();
    super.dispose();
  }

  List<ProviderCapabilities> _videoCaps() => ref
      .read(providerCapabilitiesListProvider)
      .where((c) =>
          c.modes.contains(GenerationMode.textToVideo) ||
          c.modes.contains(GenerationMode.imageToVideo))
      .toList(growable: false);

  ProviderCapabilities? _selectedCaps(List<ProviderCapabilities> all) {
    if (_providerId == null) return null;
    return all.firstWhere(
      (c) => c.providerId == _providerId,
      orElse: () => all.first,
    );
  }

  CameraMovement? _parseCamera(String? raw) {
    if (raw == null) return null;
    for (final c in CameraMovement.values) {
      if (c.name == raw) return c;
    }
    return null;
  }

  Future<void> _patch(Map<String, Object?> patch) async {
    try {
      final nodes = await ref.read(nodeRepositoryProvider.future);
      await nodes.patchTypeConfig(widget.node.id, patch);
    } catch (_) {
      // 单次保存失败静默；下次覆盖
    }
  }

  void _onPromptChanged(String v) {
    setState(() {});
    _promptDebounce?.cancel();
    _promptDebounce = Timer(_debounce, () => _patch({'prompt': v}));
  }

  Future<bool> _hasApiKey(String providerId) async {
    final secure = ref.read(secureStorageServiceProvider);
    return secure.exists(SecureStorageKeys.providerApiKey(providerId));
  }

  Future<void> _submit() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty || _providerId == null || _running) return;
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final nodes = await ref.read(nodeRepositoryProvider.future);
      await nodes.patchTypeConfig(widget.node.id, {
        'prompt': prompt,
        'provider_id': _providerId,
        if (_durationSec != null) 'duration_ms': _durationSec! * 1000,
        if (_camera != null) 'camera': _camera!.name,
      });
      final controller = await ref.read(generationControllerProvider.future);
      final outcome = await controller.submitFromConfigNode(widget.node.id);
      if (!mounted) return;
      if (outcome.succeeded) {
        messenger?.showSnackBar(
          SnackBar(content: Text(context.l10n.generationSuccess)),
        );
        final cid = widget.node.canvasId;
        if (cid != null) {
          ref.invalidate(canvasNodesControllerProvider(cid));
        }
      } else {
        final code = outcome.status.maybeMap(
          failure: (f) => f.error.code.name,
          orElse: () => 'unknown',
        );
        messenger?.showSnackBar(
          SnackBar(content: Text('${context.l10n.generationFailure}: $code')),
        );
      }
    } on MissingApiKeyError {
      messenger?.showSnackBar(
        SnackBar(content: Text(context.l10n.generationMissingKey)),
      );
    } on InvalidGenerationConfigError catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(context.l10n.generationInvalidConfig(e.reason))),
      );
    } on ProviderNotRegisteredError {
      messenger?.showSnackBar(
        SnackBar(content: Text(context.l10n.generationProviderNotRegistered)),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('${context.l10n.generationFailure}: $e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = _videoCaps();
    final selected = _selectedCaps(caps);
    final colors = context.inkColors;
    final typo = context.inkTypography;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(InkSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(left: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.inspectorTitle,
              style: typo.title.copyWith(color: colors.fg1)),
          const SizedBox(height: InkSpacing.lg),
          Text(context.l10n.inspectorVideoPromptLabel,
              style: typo.caption.copyWith(color: colors.fg3)),
          const SizedBox(height: InkSpacing.xs),
          InkInput(
            controller: _promptCtrl,
            hintText: context.l10n.inspectorPromptHint,
            minLines: 4, maxLines: 8,
            onChanged: _onPromptChanged,
          ),
          const SizedBox(height: InkSpacing.md),
          Text(context.l10n.inspectorProviderLabel,
              style: typo.caption.copyWith(color: colors.fg3)),
          DropdownButton<String>(
            value: _providerId,
            isExpanded: true,
            items: [
              for (final c in caps)
                DropdownMenuItem(value: c.providerId, child: Text(c.providerId)),
            ],
            onChanged: _running ? null : (v) {
              if (v == null) return;
              setState(() => _providerId = v);
              _patch({'provider_id': v});
            },
          ),
          const SizedBox(height: InkSpacing.md),
          if (selected != null) ...[
            Text(context.l10n.inspectorVideoDurationLabel,
                style: typo.caption.copyWith(color: colors.fg3)),
            DropdownButton<int>(
              value: _durationSec,
              isExpanded: true,
              items: [
                for (final d in selected.supportedDurations)
                  DropdownMenuItem(value: d, child: Text('$d')),
              ],
              onChanged: _running ? null : (v) {
                if (v == null) return;
                setState(() => _durationSec = v);
                _patch({'duration_ms': v * 1000});
              },
            ),
            const SizedBox(height: InkSpacing.md),
            Text(context.l10n.inspectorVideoCameraLabel,
                style: typo.caption.copyWith(color: colors.fg3)),
            DropdownButton<CameraMovement>(
              value: _camera,
              isExpanded: true,
              items: [
                for (final c in selected.supportedCameras)
                  DropdownMenuItem(value: c, child: Text(c.name)),
              ],
              onChanged: _running ? null : (v) {
                if (v == null) return;
                setState(() => _camera = v);
                _patch({'camera': v.name});
              },
            ),
          ],
          const SizedBox(height: InkSpacing.md),
          Text(context.l10n.inspectorVideoModeAuto,
              style: typo.caption.copyWith(color: colors.fg3)),
          const SizedBox(height: InkSpacing.lg),
          _VideoGenerateButton(
            prompt: _promptCtrl.text,
            providerId: _providerId,
            hasApiKey: _providerId == null
                ? Future<bool>.value(false)
                : _hasApiKey(_providerId!),
            running: _running,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _VideoGenerateButton extends StatelessWidget {
  const _VideoGenerateButton({
    required this.prompt,
    required this.providerId,
    required this.hasApiKey,
    required this.running,
    required this.onPressed,
  });
  final String prompt;
  final String? providerId;
  final Future<bool> hasApiKey;
  final bool running;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasApiKey,
      builder: (context, snap) {
        final hasKey = snap.data ?? false;
        final promptEmpty = prompt.trim().isEmpty;

        String? disabled;
        if (running) {
          disabled = null;
        } else if (promptEmpty) {
          disabled = context.l10n.inspectorVideoGenerateDisabledEmptyPrompt;
        } else if (providerId == null || !hasKey) {
          disabled = context.l10n.inspectorVideoGenerateDisabledNoKey;
        }

        final enabled =
            !running && !promptEmpty && providerId != null && hasKey;

        final child = running
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.l10n.inspectorVideoGenerate);

        final button = FilledButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        );
        return disabled != null ? Tooltip(message: disabled, child: button) : button;
      },
    );
  }
}
```

- [ ] **Step 4: 跑测试**

```bash
flutter test test/features/canvas/widgets/video_config_inspector_test.dart
flutter analyze lib/
```

- [ ] **Step 5: Commit + PR**

---

## Slice 3 — GenerationController video 分支 + remoteUrls 下载通道

**分支：** `feature/t5-s3-video-generation-pipeline`
**PR 标题：** `feat(generation): video branch + remoteUrls download pipeline (T5-S3)`

### Task 3.1: VideoDownloadService 接口 + dio 实现

**Files:**
- Create: `lib/core/interfaces/video_download_service.dart`
- Create: `lib/services/dio_video_download_service.dart`
- Create: `lib/core/di/video_download.dart`
- Test: `test/services/dio_video_download_service_test.dart`

- [ ] **Step 1: 接口定义**

`lib/core/interfaces/video_download_service.dart`:

```dart
import 'dart:io';

abstract class VideoDownloadService {
  Future<File> download({required String url, required File destination});
}

class DownloadError implements Exception {
  const DownloadError({required this.url, required this.httpStatus});
  final String url;
  final int httpStatus;
  @override
  String toString() => 'DownloadError(url=$url, httpStatus=$httpStatus)';
}
```

- [ ] **Step 2: failing 测试**

Create `test/services/dio_video_download_service_test.dart`:

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/interfaces/video_download_service.dart';
import 'package:inkframe/services/dio_video_download_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late Directory tmp;

  setUp(() async {
    dio = Dio();
    adapter = DioAdapter(dio: dio);
    tmp = await Directory.systemTemp.createTemp('video_dl_test_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('下载 200 → 文件落盘字节一致', () async {
    final bytes = List<int>.generate(256, (i) => i);
    adapter.onGet(
      'https://fake/video.mp4',
      (s) => s.reply(200, bytes, headers: {
        'content-type': ['video/mp4'],
      }),
    );

    final svc = DioVideoDownloadService(dio);
    final dst = File(p.join(tmp.path, 'out.mp4'));
    final result = await svc.download(
      url: 'https://fake/video.mp4',
      destination: dst,
    );

    expect(await result.readAsBytes(), bytes);
  });

  test('下载 404 → DownloadError(404)', () async {
    adapter.onGet('https://fake/miss.mp4', (s) => s.reply(404, 'nope'));

    final svc = DioVideoDownloadService(dio);
    expect(
      () => svc.download(
        url: 'https://fake/miss.mp4',
        destination: File(p.join(tmp.path, 'x.mp4')),
      ),
      throwsA(isA<DownloadError>().having((e) => e.httpStatus, 'status', 404)),
    );
  });
}
```

- [ ] **Step 3: 实现**

`lib/services/dio_video_download_service.dart`:

```dart
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/interfaces/video_download_service.dart';

class DioVideoDownloadService implements VideoDownloadService {
  DioVideoDownloadService(this._dio);
  final Dio _dio;

  @override
  Future<File> download({
    required String url,
    required File destination,
  }) async {
    try {
      final response = await _dio.download(
        url,
        destination.path,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == null || response.statusCode! ~/ 100 != 2) {
        throw DownloadError(url: url, httpStatus: response.statusCode ?? -1);
      }
      return destination;
    } on DioException catch (e) {
      throw DownloadError(url: url, httpStatus: e.response?.statusCode ?? -1);
    }
  }
}
```

- [ ] **Step 4: Riverpod provider**

`lib/core/di/video_download.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/video_download_service.dart';
import '../../services/dio_video_download_service.dart';

final videoDownloadServiceProvider = Provider<VideoDownloadService>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 5),
  ));
  ref.onDispose(dio.close);
  return DioVideoDownloadService(dio);
});
```

- [ ] **Step 5: 跑测试确认通过**

```bash
flutter test test/services/dio_video_download_service_test.dart
```

Expected: 2 tests PASS.

### Task 3.2: ThumbnailService 接口（占位，实现在 S4）

**Files:**
- Create: `lib/core/interfaces/thumbnail_service.dart`
- Create: `lib/core/di/thumbnail.dart`（临时 no-op）

- [ ] **Step 1: 接口**

`lib/core/interfaces/thumbnail_service.dart`:

```dart
import 'dart:io';

abstract class ThumbnailService {
  Future<File> extractFirstFrame({
    required String videoPath,
    required File destination,
  });
}

class ThumbnailError implements Exception {
  const ThumbnailError(this.reason, {this.cause});
  final String reason;
  final Object? cause;
  @override
  String toString() => 'ThumbnailError($reason)';
}
```

- [ ] **Step 2: 临时 null provider（S4 替换为 media_kit 实现）**

`lib/core/di/thumbnail.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/thumbnail_service.dart';

/// S3 临时：无实现，JobQueueService 在 `_thumbnail == null` 时跳过抽帧。
/// S4 用 MediaKitThumbnailService 替换。
final thumbnailServiceProvider = Provider<ThumbnailService?>((ref) => null);
```

### Task 3.3: JobQueueService._persistRemoteUrls 通道

**Files:**
- Modify: `lib/services/job_queue_service.dart`
- Test: `test/services/job_queue_service_remote_urls_test.dart`

- [ ] **Step 1: Read 现有 `test/services/job_queue_service_test.dart` 的 fakes**

识别 `FakeNodeRepository` / `FakeFileResolver` / `FakeJobRepository` 的接口，决定 inline copy 还是抽 helper。

- [ ] **Step 2: 写测试**

Create `test/services/job_queue_service_remote_urls_test.dart`：断言 JobSuccess(remoteUrls=[url]) → downloader 被调用 1 次，`nodeRepo.patchTypeConfig` 入参含 `'video_url'` 键值（video mode）或 `'image_url'`（image mode）。

（具体代码见 S3 落地时 inline 复用现有 fakes）

- [ ] **Step 3: 在 InMemoryJobQueueService 加 downloader + thumbnail 字段**

参数表：

```dart
    VideoDownloadService? videoDownloader,
    ThumbnailService? thumbnailService,
```

字段：

```dart
  final VideoDownloadService? _videoDownloader;
  final ThumbnailService? _thumbnail;
```

import：

```dart
import '../core/interfaces/video_download_service.dart';
import '../core/interfaces/thumbnail_service.dart';
```

- [ ] **Step 4: JobSuccess 分支扩展处理 remoteUrls**

找到 `case JobSuccess(:final inlineBytes):` —— 改为：

```dart
        case JobSuccess(:final inlineBytes, :final remoteUrls):
          if (inlineBytes != null && inlineBytes.isNotEmpty) {
            final ioErr = await _persistInlineBytes(task, inlineBytes);
            if (ioErr != null) {
              await _persistFailure(task.jobId, ioErr);
              _emitFailure(handle, ioErr);
              return;
            }
          }
          if (remoteUrls.isNotEmpty) {
            final ioErr = await _persistRemoteUrls(task, remoteUrls);
            if (ioErr != null) {
              await _persistFailure(task.jobId, ioErr);
              _emitFailure(handle, ioErr);
              return;
            }
          }
          await _persistTransition(
            task.jobId,
            from: const ['submitted', 'polling'],
            to: 'success',
            extra: {
              'completed_at': DateTime.now().toUtc().toIso8601String(),
              'progress': 1.0,
            },
          );
          handle._emit(status);
          handle._complete(status);
          return;
```

- [ ] **Step 5: 实现 `_persistRemoteUrls`**

在 `_persistInlineBytes` 下追加（见 plan 原版完整代码）。核心：
- 视频 → `videos/{jobId}.mp4`，image → `images/{jobId}.png`
- dio 下载成功 → patchTypeConfig({'video_url' OR 'image_url': relPath})
- ThumbnailService 可选：抽首帧 → `videos/{jobId}.jpg` → patch 'thumbnail_url'
- 失败：DownloadError → ProviderError / FileSystemException → LocalIOError

- [ ] **Step 6: 跑测试**

```bash
flutter test test/services/
flutter analyze lib/
```

### Task 3.4: GenerationController video 分支

**Files:**
- Modify: `lib/features/generation/generation_controller.dart`
- Test: `test/features/generation/generation_controller_video_test.dart`

- [ ] **Step 1: 扩 `submitFromConfigNode`**

读 cfgRow 后加：

```dart
    final nodeType = cfgRow['type'] as String? ?? 'image';
    if (nodeType != 'image' && nodeType != 'video') {
      throw const InvalidGenerationConfigError('unsupported node type');
    }
```

result 节点 create：

```dart
    final resultNodeId = await nodes.create(
      canvasId: canvasId,
      type: nodeType, // 'image' or 'video'
      nodeRole: 'result',
      sourceNodeId: configNodeId,
    );
```

jobs.create：

```dart
        jobType: nodeType,
```

mode 推断：

```dart
    final GenerationMode mode;
    int durationSeconds = 0;
    CameraMovement? cameraEnum;
    if (nodeType == 'video') {
      mode = refs.refImagePaths.isEmpty
          ? GenerationMode.textToVideo
          : GenerationMode.imageToVideo;
      final durMs = typeConfig['duration_ms'];
      durationSeconds = durMs is int ? durMs ~/ 1000 : 0;
      final camRaw = typeConfig['camera'];
      if (camRaw is String) {
        for (final c in CameraMovement.values) {
          if (c.name == camRaw) cameraEnum = c;
        }
      }
    } else {
      mode = refs.refImagePaths.isEmpty
          ? GenerationMode.textToImage
          : GenerationMode.imageToImage;
    }
```

`GenerationTask(...)` 加 `durationSeconds: durationSeconds, camera: cameraEnum`。

- [ ] **Step 2: 视频分支测试**

断言：
- video cfg 节点 → 创建 resultNode.type == 'video'
- 无 data edge → task.mode == GenerationMode.textToVideo
- 有 reference edge → task.mode == GenerationMode.imageToVideo
- durationSeconds / camera 从 typeConfig 映射正确

### Task 3.5: wire JobQueue DI 注入 downloader + thumbnail

**Files:**
- Modify: `lib/core/di/job_queue.dart`

- [ ] **Step 1: provider wire**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/job_queue_service.dart';
import '../../services/job_queue_service.dart';
import 'file_resolver.dart';
import 'providers.dart';
import 'repositories.dart';
import 'thumbnail.dart';
import 'video_download.dart';

final jobQueueServiceProvider = Provider<JobQueueService>((ref) {
  final registry = ref.watch(providerRegistryProvider);
  final nodeRepoAsync = ref.watch(nodeRepositoryProvider);
  final jobRepoAsync = ref.watch(jobRepositoryProvider);
  final downloader = ref.watch(videoDownloadServiceProvider);
  final thumbnail = ref.watch(thumbnailServiceProvider);
  final resolver = ref.watch(fileResolverServiceProvider);

  final service = InMemoryJobQueueService(
    registry: registry,
    nodeRepo: nodeRepoAsync.valueOrNull,
    jobRepo: jobRepoAsync.valueOrNull,
    fileResolver: resolver,
    videoDownloader: downloader,
    thumbnailService: thumbnail,
  );
  ref.onDispose(service.dispose);
  return service;
});
```

（具体参数表以 `InMemoryJobQueueService` 现有构造器为准，缺哪个补哪个。）

- [ ] **Step 2: 全套回归**

```bash
flutter test
flutter analyze lib/
```

### Task 3.6: Commit + PR

```bash
git checkout -b feature/t5-s3-video-generation-pipeline
git add <新建 + 修改文件>
git commit -m "feat(generation): video branch + remoteUrls download pipeline (T5-S3)"
git push -u origin feature/t5-s3-video-generation-pipeline
gh pr create --base dev ...
```

---

## Slice 4 — ThumbnailService + NodeCard 视频 body

**分支：** `feature/t5-s4-video-node-body`
**PR 标题：** `feat(canvas): NodeCard video body + thumbnail (T5-S4)`

### Task 4.1: MediaKitThumbnailService 实现

**Files:**
- Create: `lib/services/media_kit_thumbnail_service.dart`
- Modify: `lib/core/di/thumbnail.dart`

- [ ] **Step 1: 实现**

`lib/services/media_kit_thumbnail_service.dart`:

```dart
import 'dart:io';

import 'package:media_kit/media_kit.dart';

import '../core/interfaces/thumbnail_service.dart';

class MediaKitThumbnailService implements ThumbnailService {
  @override
  Future<File> extractFirstFrame({
    required String videoPath,
    required File destination,
  }) async {
    final player = Player();
    try {
      await player.open(Media(videoPath), play: false);
      await player.seek(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final bytes = await player.screenshot(format: 'image/jpeg');
      if (bytes == null || bytes.isEmpty) {
        throw const ThumbnailError('screenshot returned empty');
      }
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(bytes);
      return destination;
    } catch (e) {
      if (e is ThumbnailError) rethrow;
      throw ThumbnailError('media_kit_failed', cause: e);
    } finally {
      await player.dispose();
    }
  }
}
```

- [ ] **Step 2: provider 换真实现**

`lib/core/di/thumbnail.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/thumbnail_service.dart';
import '../../services/media_kit_thumbnail_service.dart';

final thumbnailServiceProvider = Provider<ThumbnailService?>((ref) {
  return MediaKitThumbnailService();
});
```

### Task 4.2: 手动回归清单

**Files:**
- Create: `docs/internal/t5-manual-regression.md`

内容：

```markdown
# T5 手动回归清单

- [ ] 在 canvas 新建 video 节点 → Inspector 显示 prompt / duration / camera
- [ ] 点 Generate → 观察 result 节点占位（旋转圆）出现
- [ ] 等待 wanx-t2v 结束（~30s） → result 节点显示缩略图
- [ ] 点 result 节点 → 灯箱打开并播放视频
- [ ] 关灯箱 → 节点状态保持缩略图
- [ ] data edge 连 image → video config → Inspector 下方 inputs 列出
- [ ] 再次 Generate → task.mode 应为 imageToVideo（从日志确认）
- [ ] 删视频节点 → edges 级联软删
- [ ] 重启 app → 视频节点从 DB 水化，缩略 + 灯箱正常
```

### Task 4.3: NodeCard video result body

**Files:**
- Create: `lib/features/canvas/widgets/video_node_body.dart`
- Modify: `lib/features/canvas/widgets/node_card.dart`
- Test: `test/features/canvas/widgets/video_node_body_test.dart`

- [ ] **Step 1: Widget 测试（3 cases）**

- 无 `videoUrl` → 占位 `hourglass_empty_outlined`
- 有 `thumbnail_url` 但文件缺失 → `broken_image_outlined`
- 有 `video_url` 无 `thumbnail_url` → `play_circle_outline`

- [ ] **Step 2: 实现 VideoNodeBody**

状态机：
- 无 `videoUrl` → 占位 "等待生成"
- 有 `thumbnailUrl` → Image.file(thumbnail) + play icon overlay
- 有 `videoUrl` 但 thumbnail 未抽 → 纯 play icon + surface3 底色
- thumbnail 文件缺失 → broken 占位

（完整代码见原 plan 的 Task 4.3 Step 3）

- [ ] **Step 3: node_card 分流**

修改 `_ResultBody.build`：

```dart
  @override
  Widget build(BuildContext context) {
    return switch (node.type) {
      CanvasNodeType.video => VideoNodeBody(node: node),
      _ => _buildImageResult(context),
    };
  }
```

---

## Slice 5 — VideoPlayerService + VideoLightbox

**分支：** `feature/t5-s5-video-lightbox`
**PR 标题：** `feat(canvas): VideoLightbox full-screen play (T5-S5)`

### Task 5.1: VideoPlayerService 接口 + media_kit 实现

**Files:**
- Create: `lib/core/interfaces/video_player_service.dart`
- Create: `lib/services/media_kit_video_player_service.dart`
- Create: `lib/core/di/video_player.dart`

- [ ] **Step 1: 接口**

`lib/core/interfaces/video_player_service.dart`:

```dart
abstract class VideoPlayerService {
  VideoPlayerHandle create();
}

abstract class VideoPlayerHandle {
  Future<void> open(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration at);
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Future<void> dispose();

  /// media_kit 的 Player 对象 —— 仅给 media_kit_video 的 Video widget 用。
  Object get rawPlayer;
}
```

- [ ] **Step 2: media_kit 实现 + provider**

见原 plan Task 5.1 Step 2 / 3 完整代码。

- [ ] **Step 3: main.dart 初始化**

```dart
import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: InkFrameApp()));
}
```

### Task 5.2: VideoLightbox widget

**Files:**
- Create: `lib/features/canvas/widgets/video_lightbox.dart`
- Modify: `lib/l10n/app_en.arb`, `app_zh.arb`（`lightboxClose` / `lightboxPlayPause`）

Dialog 形式全屏：
- `showVideoLightbox(context, videoPath: ...)` helper
- `VideoLightboxContent` stateful：initState 拿 handle + Video widget，dispose 释放
- 控制条：play/pause + position slider + duration 文本

（完整代码见原 plan Task 5.2 Step 2）

### Task 5.3: NodeCard tap → Lightbox

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_view.dart`

定位 tap handler，判断：

```dart
if (node.type == CanvasNodeType.video &&
    node.role == NodeRole.result &&
    node.videoUrl != null &&
    node.projectId != null &&
    node.canvasId != null) {
  final resolver = ref.read(fileResolverServiceProvider);
  try {
    final file = resolver.resolve(
      projectId: node.projectId!,
      canvasId: node.canvasId!,
      relativePath: node.videoUrl!,
    );
    if (file.existsSync()) {
      await showVideoLightbox(context, videoPath: file.path);
      return;
    }
  } on PathSecurityError {
    // fall through
  }
}
```

---

## Slice 6 — Add Video Node FAB 菜单

**分支：** `feature/t5-s6-add-video-fab`
**PR 标题：** `feat(canvas): Add Video Node FAB menu (T5-S6)`

### Task 6.1: FAB → PopupMenu

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/l10n/app_en.arb`, `app_zh.arb`（`canvasAddVideoNode` / `canvasAddNodeTooltip`）

把 `_AddNodeFab.build` 替换为 `PopupMenuButton<CanvasNodeType>`，两项：
- image → `canvasAddImageNode` + `add_photo_alternate_outlined`
- video → `canvasAddVideoNode` + `videocam_outlined`

`onSelected` 调 `_addNode(context, ref, type)`，把 `addNode(type: type, ...)` 传下去。

（完整代码见原 plan Task 6.1 Step 2）

---

## Slice 7 — Release v0.1.0-alpha.8

**分支：** `release/v0.1.0-alpha.8`

### Task 7.1: 全测试 + 手动回归

```bash
flutter test
flutter analyze lib/
```

按 `docs/internal/t5-manual-regression.md` 过一遍。

### Task 7.2: 更新 BUILD-RELEASE.md

追加 media_kit 平台依赖段落：
- macOS: libmpv dylib 自动 codesign
- Windows: libmpv.dll 捆绑，安装包 +~40MB

### Task 7.3: 更新 spec + release PR + tag

- 修正 `docs/specs/2026-04-22-t5-direction-candidates.md` "6 款" → "5 款"，追加 T5 收口段
- release PR 到 main，**Rebase & merge**（CONTRIBUTING §69）
- `./scripts/release-tag.sh v0.1.0-alpha.8 "$MERGE_SHA"`（TD-002 SHA 入参护栏）

---

## Self-Review

### Spec 覆盖

| 需求 | 落地 |
|---|---|
| 5 款视频 Provider user-visible | S2 + S3 |
| t2v / i2v 模式切换 | S3 Task 3.4 |
| duration / camera / aspect | S2 Task 2.4 |
| NodeCard 视频缩略图 | S4 |
| 灯箱全屏播放 + 进度条 | S5 |
| Add Video Node FAB | S6 |
| 首末帧 data edge 复用（#39）| S3 Task 3.4（`refs.firstFramePath/lastFramePath` 已在 controller 内拉） |
| §5.5 提取帧 | **排除** defer T5.1 |
| 批量视频 | **排除** 当前 Provider batch_size=1 |

### 类型一致性

| 类型 / 签名 | 一致 |
|---|---|
| `VideoDownloadService.download({required url, required destination})` | ✅ S3 定义 → S3 使用 |
| `ThumbnailService.extractFirstFrame({required videoPath, required destination})` | ✅ S3 定义 → S3 使用 → S4 实现 |
| `VideoPlayerHandle.open(String filePath)` | ✅ S5 |
| `CanvasNode.videoUrl / thumbnailUrl / durationMs / cameraName / videoMode` | ✅ S1 定义 → S2 + S4 使用 |
| `GenerationMode.textToVideo / imageToVideo` + `CameraMovement` | ✅ 既有 enum |

### 依赖 DAG

```
S0 (ADR docs) ──┐ 独立
S1 (model + deps) ──┐
                    ├─→ S2 (Inspector)
                    ├─→ S3 (Pipeline)
                    │    └─→ S4 (NodeCard video)
                    │         └─→ S5 (Lightbox)
                    └─→ S6 (FAB)
                         └─→ S7 (Release)
```

S0 与 S1 可并行；S2 与 S3 可并行（均只依赖 S1）；S4 依赖 S3；S5 依赖 S4；S6 依赖 S1；S7 依赖全部。

### 已知风险

| 风险 | 消缓 |
|---|---|
| media_kit headless CI 跑不过 screenshot | ThumbnailService 抽接口，测试用 Fake；真实走手动回归 |
| DashScope remoteUrls 短 TTL | `_persistRemoteUrls` 在 JobSuccess 内同步下载；失败转 LocalIOError 用户重试 |
| libmpv 打包体积 ~40MB | BUILD-RELEASE.md 通告 |
| Lightbox dispose 时机 | initState/dispose 对称调用 handle.dispose |
| Plugin registrant 漏 commit | S1 commit 清单含 3 个 generated registrant 文件 |

---

## Execution Handoff

Plan saved. Sprint 按 Subagent-Driven 推进，每个 Slice fresh agent + PR 间 review。

注：per user memory 的 "计划写完不要直接执行"——Plan 落地后等用户 approve 才起第一个 Slice。
