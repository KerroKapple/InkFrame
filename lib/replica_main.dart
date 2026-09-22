// 静态复刻专用入口（B 路径验收工具，不进正式 app）：
//   flutter run -d windows -t lib/replica_main.dart
//   flutter run -d windows -t lib/replica_main.dart --dart-define=INKFRAME_REPLICA_OUT=D:/x.png
//
// 不起 PG、不读偏好、不走 window_manager。页面固定 1600×1000 逻辑像素放在可滚动视口里；
// 给了 INKFRAME_REPLICA_OUT 时首帧后按 pixelRatio=1 把 RepaintBoundary 截成 PNG 落盘并退出——
// 截图与显示器 DPI 无关，可直接和稿在浏览器 1600×1000 的截图并排。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter/rendering.dart';

import 'features/workspace/workspace_v2_screen.dart';
import 'theme/app_theme.dart';

const String _kOut = String.fromEnvironment('INKFRAME_REPLICA_OUT');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ReplicaApp());
}

class _ReplicaApp extends StatelessWidget {
  const _ReplicaApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: const _ReplicaHost(),
    );
  }
}

class _ReplicaHost extends StatefulWidget {
  const _ReplicaHost();

  @override
  State<_ReplicaHost> createState() => _ReplicaHostState();
}

class _ReplicaHostState extends State<_ReplicaHost> {
  final GlobalKey _boundary = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (_kOut.isNotEmpty) {
      // 等两帧：首帧后字体可能仍在异步解析，第二帧再截。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
      });
    }
  }

  Future<void> _capture() async {
    final RenderRepaintBoundary boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(_kOut).writeAsBytes(bytes!.buffer.asUint8List());
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.inkColors.surface0,
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: RepaintBoundary(
            key: _boundary,
            child: const WorkspaceV2Screen(),
          ),
        ),
      ),
    );
  }
}
