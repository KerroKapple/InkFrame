// 截图脚手架：和 golden 走同一条渲染路径，但**只落盘不比对**。
//
// 为什么要这条路：原来的接线截图靠本机跑未签名的 debug exe
// （`dev_capture.dart` + `INKFRAME_CAPTURE_*`），机器安全策略一收紧就卡住
// （2026-09-30 Device Guard 拦过一次），而那套工具又和复刻夹具绑死、随 #245
// 一起删了。走 widget test 的好处是：和 `matchesGoldenFile` 同一条 Skia 渲染路径、
// 同一份内存仓储播种，能在 CI 上跑，不需要起真 app、不需要内嵌 PG、不需要 media_kit。
//
// 代价是**字体**：`test/flutter_test_config.dart` 把「Noto Sans SC」别名到了
// Roboto 的字节（为的是让度量稳定），而 Roboto 没有中文字形——所以现有 golden
// 全是英文界面。截图是给人看的、必须是中文，于是这里要再装一次真的中文字体。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

/// 探测顺序：优先**单体 ttf/otf**，再退到 ttc 字体集合。
///
/// ttc 是多字体打包，`FontLoader` 塞进去只拿得到第一张脸，不同系统第一张是谁
/// 并不保证——所以能用单体就不用集合。
const List<String> _kCjkFontCandidates = <String>[
  // Windows：SimHei 是单体 ttf，最省事；微软雅黑是 ttc，放后面兜底。
  r'C:\Windows\Fonts\simhei.ttf',
  r'C:\Windows\Fonts\msyh.ttc',
  // Linux（CI ubuntu 需先 apt-get install fonts-noto-cjk）。
  '/usr/share/fonts/opentype/noto/NotoSansCJK-SC-Regular.otf',
  '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
  // macOS。
  '/System/Library/Fonts/PingFang.ttc',
];

/// 把一份真的中文字体装进测试 Skia，覆盖 flutter_test_config 的 Roboto 别名。
///
/// 返回命中的字体路径；一个都找不到返回 null——**调用方据此跳过**，不要让它
/// 静默出一张全是方框的图，那比没有图更坏（看图的人会以为是界面坏了）。
Future<String?> loadRealCjkFont() async {
  for (final String path in _kCjkFontCandidates) {
    final File f = File(path);
    if (!f.existsSync()) continue;
    try {
      final Uint8List bytes = await f.readAsBytes();
      // 用同一个族名再装一次：后装的覆盖先装的别名。
      final FontLoader loader = FontLoader('Noto Sans SC')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      return path;
    } on FileSystemException {
      continue;
    }
  }
  return null;
}

/// 把 [key] 标记的那棵子树渲成 PNG 落到 [outPath]。
///
/// 必须在 `tester.runAsync` 里调 `toImage`——它要等真正的 GPU/光栅回调，
/// 而 widget test 默认把异步时钟架空了，不 runAsync 会永远挂着。
Future<File> captureToPng(
  WidgetTester tester,
  Key key,
  String outPath, {
  double pixelRatio = 1.0,
}) async {
  final RenderRepaintBoundary boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final File out = File(outPath);
  out.parent.createSync(recursive: true);

  final Uint8List? png = await tester.runAsync<Uint8List?>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });

  if (png == null) {
    throw StateError('截图失败：toImage 没有返回像素（$outPath）');
  }
  out.writeAsBytesSync(png);
  return out;
}

/// 截图场景的 RepaintBoundary key。
const Key kScreenshotBoundary = Key('screenshot-boundary');

/// 装配一屏截图场景：固定 size、暗主题、**中文 locale**、整屏铺满。
///
/// 与 `pumpGoldenScene` 的区别只有三点，其余刻意保持一致（同一条渲染路径）：
/// locale 默认 zh（截图给人看）、不套 `Center`（要整屏而不是居中的一小块）、
/// 外面包一层 RepaintBoundary 好让 `captureToPng` 抓得到。
Future<void> pumpScreenshotScene(
  WidgetTester tester,
  Widget child, {
  required Size size,
  List<Override> overrides = const <Override>[],
  Locale locale = const Locale('zh'),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        // 必须有 Scaffold：没有 Material 祖先时文字会被画上黄底红字的调试下划线
        // （踩过——截出来整屏文字都带下划线）。真实 app 里这些屏也是挂在
        // InkShell 的 Scaffold 下，所以这里套一层才是和生产一致的渲染。
        home: RepaintBoundary(
          key: kScreenshotBoundary,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 截图输出目录。默认 `build/screenshots/`（gitignored），
/// 可用 `INKFRAME_SHOT_DIR` 指到别处（例如 CI 的 artifact 目录）。
String get screenshotDir => const String.fromEnvironment(
      'INKFRAME_SHOT_DIR',
      defaultValue: 'build/screenshots',
    );
