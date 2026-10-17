# dep-drop-pasteboard · 引入 desktop_drop + pasteboard，封装系统剪贴板读图接口
- 波次 W9 / lane C / 基底：origin/main（W0–W8 已合入）；依赖切片：无；阻塞决定：IS-Q1 → A（desktop_drop + pasteboard）

## 目标（用户看到什么变化，2–4 行）
- 用户看不到变化，这一片只打底座。
- 应用装上两个原生插件：desktop_drop 用来从 Finder / 资源管理器拖文件进来，pasteboard 用来读系统剪贴板里的图片和文件。
- 新增一个接口 `SystemClipboardImageService`，所有「读剪贴板图 / 文件」都走它。它把 Windows 读出的 BMP 统一转成 PNG，写进临时文件交出去。下一片 os-drop-paste-image 只用这个接口，不再另建 reader。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/ImportSearch.dc.html`「需要你定 1」：A = desktop_drop + pasteboard 两个小插件（建议 A）；B 带 Rust 原生库，构建变重。画布内复制节点走应用内剪贴板，往系统剪贴板只写纯文字，这件事两案都不需要新依赖。
- 同板「导入媒体」：「需要：拖入要 desktop_drop，读剪贴板图片要 pasteboard（需定 1，全部画板的粘贴 / 拖放以此为准）」；导入白名单是 png / jpg / webp / mp4 / mov / webm（W2 media-import-service）。
- `b2/project/UndoClipboard.dc.html`「系统剪贴板」：图片 → 图像产物节点，读图依赖见导入与查找「需要你定 1」，与拖入共用一套。
- 设计缺口：画板只说「读剪贴板图片」。但 Finder / 资源管理器「复制文件」放进剪贴板的是文件路径：Windows 是 CF_HDROP，没有 CF_DIB；mac 上 NSImage 可能读出文件图标。所以本接口同时提供 `readFilePaths()`，由下一片规定「先文件、后图片」。
- 设计缺口：Windows 剪贴板图片经插件转出来是 32 位 XRGB 的 BMP，透明通道丢失。本片转 PNG 时 alpha 一律置 255。也就是说透明 PNG 从 Windows 剪贴板贴进来会带黑底，这是插件的上限，写进风险。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

**执行代理手写的部分**
- `pubspec.yaml`：在 `dependencies:` 的 `ffi: ^2.2.0` 之后加两行，各带一行中文注释：
  - `desktop_drop: ^0.8.4`，注释「系统文件拖入画布（ImportSearch Q1 A）」；
  - `pasteboard: ^0.5.0`，注释「读系统剪贴板图片 / 文件（同 Q1 A）」。
  - 不动别的依赖。
- 新 `lib/core/interfaces/system_clipboard_image_service.dart`：接口 + sealed 读取结果，签名见下。
- 新 `lib/services/pasteboard_clipboard_image_service.dart`：
  - `PasteboardClipboardImageService` 实现；
  - 插件缝 `PasteboardGateway` 和它的默认实现 `PasteboardPluginGateway`，后者是唯一调用 `Pasteboard.image` / `Pasteboard.files()` 的地方；
  - 纯函数 `bmp32ToPng`。
- 新 `lib/core/di/clipboard_image.dart`：`systemClipboardImageServiceProvider`（app 级 Provider）。
- 新测试 `test/services/pasteboard_clipboard_image_service_test.dart`。

**主 Agent 生成并提交的部分（执行代理不要手写、不要伪造）**
- `pubspec.lock`、`windows/flutter/generated_plugin_registrant.cc`、`windows/flutter/generated_plugins.cmake`、`macos/Flutter/GeneratedPluginRegistrant.swift`：主 Agent 在合入前跑 `flutter pub get` 生成，和代码同一个提交。
- 生成后用 `git diff` 核对，应只有下面这些增量（插件按名字字母序插入）：
  - `.cc`：`#include <desktop_drop/desktop_drop_plugin.h>`、`#include <pasteboard/pasteboard_plugin.h>`，以及 `DesktopDropPluginRegisterWithRegistrar(registry->GetRegistrarForPlugin("DesktopDropPlugin"));`、`PasteboardPluginRegisterWithRegistrar(registry->GetRegistrarForPlugin("PasteboardPlugin"));`。
  - `.cmake`：`FLUTTER_PLUGIN_LIST` 里加 `desktop_drop` 和 `pasteboard`。
  - `.swift`：加 `import desktop_drop`、`import pasteboard`，以及 `DesktopDropPlugin.register(with: registry.registrar(forPlugin: "DesktopDropPlugin"))`、`PasteboardPlugin.register(with: registry.registrar(forPlugin: "PasteboardPlugin"))`。
  - `pubspec.lock`：只新增 `desktop_drop 0.8.4` 和 `pasteboard 0.5.0` 两个条目。它们的依赖 cross_file、web、universal_platform、dbus、uuid、path 现在的锁里都已经有了，不应升级别的包；如果有升级，就是版本选错了，退回重选。
- `macos/Podfile.lock`：只有在 macOS 上跑 `pod install`（或 `flutter build macos`）才会更新。主 Agent 没有 mac 就不改它，也不要手改（SPEC CHECKSUMS 是 podspec 的哈希）。release.yml 的 macos-14 job 会在构建时自己 `pod install`，旧 lock 不阻断。等第一位在 mac 上构建的人补提交。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- os-drop-paste-image（同 lane 下一片）：`widgets/canvas_view.dart`、`widgets/shortcuts/clipboard_keys.dart`、`util/canvas_paste_actions.dart`、`widgets/os_file_drop_overlay.dart`、`util/import_drop_summary.dart`、`util/canvas_import_drop_actions.dart`。本片不接任何 UI。
- canvas-find-bar：`widgets/canvas_screen.dart`、`widgets/node_card_slot.dart`、`widgets/node_card.dart`、`util/escape_ladder.dart`。
- job-eta：`lib/storage/repositories/postgres_job_repository.dart`。
- multi-select-inspector：`widgets/canvas_inspector_panel.dart`、`widgets/image_config_inspector.dart`、`widgets/video_config_inspector.dart`。
- rail-drag-characters：`widgets/character_library_panel.dart`、`util/ref_image_budget.dart`。
- outline-rename-menu：`widgets/left_rail/outline_panel.dart`、`providers/canvas_nodes_controller.dart`、`models/canvas_command.dart`。
- 通用：
  - `util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`widgets/canvas_shortcuts.dart` 骨架；
  - `lib/core/licenses.dart`：不需要登记，理由见「风险」；
  - W2 的 `lib/core/interfaces/media_import_service.dart` 和 `lib/services/file_media_import_service.dart`。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：rail-drag-characters：`lib/features/canvas/widgets/characters_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// lib/core/interfaces/system_clipboard_image_service.dart（纯 Dart，不 import Flutter / 插件）
sealed class ClipboardImageRead { const ClipboardImageRead(); }
final class ClipboardImageNone extends ClipboardImageRead {}                 // 剪贴板里没有图
final class ClipboardImagePng extends ClipboardImageRead {                   // 已规范成 PNG，落在临时文件
  final String tempFilePath; final int width; final int height; }
enum ClipboardImageUnsupportedReason { format, tooLarge }
final class ClipboardImageUnsupported extends ClipboardImageRead { final ClipboardImageUnsupportedReason reason; }
final class ClipboardImageReadFailed extends ClipboardImageRead {}           // 平台报错（如 Windows 剪贴板被占用）
abstract class SystemClipboardImageService {
  Future<List<String>> readFilePaths();          // Finder / 资源管理器「复制文件」；没有 / 失败 → 空表
  Future<ClipboardImageRead> readImage();
  Future<void> releaseTemp(String tempFilePath); // 调用方导入完（成败都要）必须调；文件不存在也不抛
}
// lib/services/pasteboard_clipboard_image_service.dart
abstract class PasteboardGateway { Future<Uint8List?> image(); Future<List<String>> files(); }
class PasteboardPluginGateway implements PasteboardGateway { const PasteboardPluginGateway(); }
class PasteboardClipboardImageService implements SystemClipboardImageService {
  PasteboardClipboardImageService({required PasteboardGateway gateway, required Directory tempRoot,
      required Clock clock, required LoggerService logger});
}
const int kMaxClipboardImageBytes = 256 * 1024 * 1024;   // 原始字节上限，超了 → tooLarge
const String kClipboardTempDirName = 'inkframe-clipboard';
@visibleForTesting Uint8List? bmp32ToPng(Uint8List bmp);  // 只认 BI_RGB / BI_BITFIELDS 的 24 / 32 位、自下而上或自上而下；其余 → null
// lib/core/di/clipboard_image.dart
final systemClipboardImageServiceProvider = Provider<SystemClipboardImageService>(...); // gateway const、tempRoot = Directory.systemTemp、clockProvider、loggerProvider
```
- `readImage` 流程：
  1. `gateway.image()` 返回 null → `None`。
  2. 字节数超过上限 → `Unsupported(tooLarge)`。
  3. 看文件头魔数：`89 50 4E 47` 是 PNG，原样用；`42 4D`（"BM"）是 BMP，在 `Isolate.run` 里调 `bmp32ToPng`，返回 null 就 `Unsupported(format)`；其余（TIFF / JPEG 等，插件目前不会给）→ `Unsupported(format)`。
  4. 宽高用 `core/media/png_dimensions.dart` 的 `pngDimensions` 读。
  5. 写临时文件：先写 `<tempRoot>/inkframe-clipboard/clipboard-<yyyyMMdd-HHmmss>.png.partial`，再改名去掉 `.partial`。时间取注入的 clock，重名追加 `-2`、`-3`。
  6. 返回 `Png`。
- 文件名 `clipboard-<时间>.png` 会成为导入节点的 original_name，它是文件标识，不进 ARB。
- 异常：只捕 `PlatformException` 和 `MissingPluginException`（→ `ReadFailed` / 空表，并 `logger.warn('clipboard_image', ...)`），以及 `FileSystemException`（写临时文件失败 → `ReadFailed`，清掉 `.partial`）。不捕 Exception。
- `bmp32ToPng` 是纯 Dart：
  - 解析 BITMAPFILEHEADER + BITMAPINFOHEADER，按 biHeight 正负决定行序，BGRX → RGBA，alpha 一律 255。
  - IDAT 用 `dart:io` 的 `zlib.encode`，CRC 用 `package:archive` 的 `getCrc32`（archive 4.0.9 已是直接依赖），每行 filter 0。
  - 不经 dart:ui 解码，因为 dart:ui 失败时抛的是裸 Exception，按项目规则不许捕。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 网关给 PNG 字节（mac 插件总是把 NSImage 转成 PNG）→ `Png`。临时文件的内容与输入逐字节相同，宽高与 IHDR 一致。
2. 网关给 32 位自下而上的 BMP（Windows 插件经 CreateBMPFile 产出）→ `Png`。解出的第 0 行像素等于 BMP 最后一行，每个像素 alpha = 255。
3. 24 位 BMP（行宽按 4 字节对齐、有填充）→ 正确解出，填充字节不进像素。
4. biCompression 是 RLE，或者位深是 8 / 16 → `Unsupported(format)`，不写临时文件。
5. 截断的 BMP（头里声称的尺寸大于实际字节）→ `bmp32ToPng` 返回 null → `Unsupported(format)`，不抛 RangeError。实现要先校验长度。
6. 网关返回 null → `None`；返回空 `Uint8List` → `None`。
7. 网关抛 `PlatformException`（Windows「open clipboard failed」）→ `ReadFailed`，记一条 warn，不往外抛。
8. 网关抛 `MissingPluginException`（测试环境、未注册插件）→ `ReadFailed`。`readFilePaths` 遇到同样情况返回空表。
9. 字节数 > `kMaxClipboardImageBytes` → `Unsupported(tooLarge)`，不解码。
10. 临时目录不可写（`FileSystemException`）→ `ReadFailed`，目录里不留 `.partial`。
11. 同一秒内读两次：第二个文件名带 `-2`，两个文件都在，互不覆盖。
12. `releaseTemp(path)` 删掉文件；文件已经不在了也不抛。只许删 `tempRoot/inkframe-clipboard/` 下的路径，给别的路径什么都不做并记 warn，防止误删。
13. `readFilePaths` 原样返回网关给的路径，不过滤扩展名，过滤是 import_drop_summary 的事。网关抛平台异常时返回空表。
14. mac / Windows 差异全部收在本服务里，调用方看不到平台：mac 给 PNG，Windows 给 BMP 再转 PNG。Windows 丢透明（规则 2 的 alpha = 255）。Linux 不在支持平台内，插件照装，不另做适配。
15. 本片不注册任何拖放 widget。desktop_drop 只进依赖，`DropTarget` 由下一片接进 canvas_view。

## 新文案键（key · en · zh 表；没有写无）
无。本片没有用户可见文案，日志 module 用英文常量 `clipboard_image`。

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/services/pasteboard_clipboard_image_service_test.dart`（新；fake `PasteboardGateway` + `Directory.systemTemp.createTemp` + 固定 clock + 记录型 fake logger）：
  - `png passthrough writes identical bytes and reports IHDR size`（规则 1）。
  - `bottom-up 32bpp bmp converts to png with flipped rows and opaque alpha`（规则 2：手工拼一个 2×2 的 BMP，用 `pngDimensions` 解码校验，再用 `zlib.decode` 解 IDAT 比像素）。
  - `24bpp bmp with row padding converts`（规则 3）。
  - `rle or 8bpp bmp is unsupported format, no temp file`（规则 4）。
  - `truncated bmp is unsupported, does not throw`（规则 5）。
  - `null and empty bytes → none`（规则 6）。
  - `PlatformException → readFailed and logs warn`（规则 7）。
  - `MissingPluginException → readFailed; files → empty`（规则 8）。
  - `oversize → tooLarge without decoding`（规则 9：gateway 返回长度超限的字节，断言 `bmp32ToPng` 没被调用，可以用计数 spy 或只校验返回类型 + 目录为空）。
  - `unwritable temp root → readFailed, no .partial left`（规则 10）。
  - `two reads in same second get distinct names`（规则 11）。
  - `releaseTemp deletes, tolerates missing, refuses outside dir`（规则 12）。
  - `readFilePaths passes through`（规则 13）。
- 现有 `test/quality/no_direct_instantiation_test.dart` 必须仍然是绿的：只有 `core/di/clipboard_image.dart` 里 new 了服务。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. BMP 行序不翻转（按自上而下读）→ `bottom-up 32bpp bmp converts…` 变红。
2. alpha 取 BMP 第 4 字节，不置 255 → 同一条变红（输入里那个字节是 0）。
3. 24 位时不跳行填充 → `24bpp bmp with row padding converts` 变红。
4. 去掉长度校验 → `truncated bmp is unsupported, does not throw` 变红（会抛 RangeError）。
5. `PlatformException` 分支删掉 → `PlatformException → readFailed` 变红。
6. 去掉 `.partial` 改名，直接写最终名 → `unwritable temp root → … no .partial left` 用例里改成断言「先出现 .partial」的那一步变红。写法：fake 目录里在改名前探查一次。
7. `releaseTemp` 去掉目录边界判断 → `refuses outside dir` 变红。
8. 时间戳不去重 → `two reads in same second get distinct names` 变红。
9. 超限判断挪到解码之后 → `oversize → tooLarge without decoding` 变红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 主 Agent 先跑 `flutter pub get`，核对 lock 和三个注册文件的增量与「允许改的文件」一节一致。然后跑 `flutter analyze lib test`、`flutter test test/services/pasteboard_clipboard_image_service_test.dart test/quality`，再逐条跑上面 9 个变异。
- 发版前要在真机冒烟，CI 做不了：
  - Windows：Win+Shift+S 截图后读出 PNG，资源管理器复制文件后 `readFilePaths` 有路径；
  - mac：⌘⌃⇧4 截图读出 PNG。
- 无 UI，不截图。

## 风险与不确定
- 版本选择理由：
  - desktop_drop 最新是 0.9.1（2026-10-17 发布）和 0.9.0，二者都要求 Dart ^3.13.5 / Flutter ≥ 3.47.7，高于 CI 的 3.41.6，而且发布不足两周，所以排除。0.8.4（2026-09-01）是能用的最新版，`^0.8.4` 自动封顶在 0.9.0 以下。
  - pasteboard 0.5.0（2026-02-24）是最新版，要求 Dart ≥ 3.4 / Flutter ≥ 3.22。
  - 两个包都是 Apache-2.0。
- license：两者都是 pub 包，它们的 LICENSE 由 Flutter 构建时自动聚合进 NOTICES，`showLicensePage` 能看到。`lib/core/licenses.dart` 只登记非 pub 的原生二进制和字体（见文件头注），两个插件也没有另带第三方原生库，所以不需要登记。
- Windows 剪贴板图丢透明（插件用 XRGB8888），透明 PNG 会带黑底。若用户反馈强烈，后续可以改读 "PNG" 剪贴板格式，但那需要换插件或补原生代码，超出本片。
- `flutter pub get` 在 Linux 上通常也会重写 macOS / Windows 的注册文件。如果主 Agent 发现哪个文件没变，就按「允许改的文件」一节列出的增量手补，并在 PR 描述里写明是手补的。
- 以管理员身份运行时，Windows 会拦截从普通权限资源管理器拖进来的文件（UIPI）。这是系统行为，留给下一片在风险里提示。
