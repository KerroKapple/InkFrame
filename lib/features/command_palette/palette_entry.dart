// 命令面板的结果条目（Screens 稿第 4 屏右：镜头 / 产物 / 动作三组）。
//
// 「设置项」组仓库没有索引，不做全量加载，不出现（用户 2026-09-23）。
// 手写不可变值对象（同 ShellState：build_runner 工具链受阻）。
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PaletteGroup { shots, artifacts, actions }

typedef PaletteRun = Future<void> Function(BuildContext context, WidgetRef ref);

@immutable
class PaletteEntry {
  const PaletteEntry({
    required this.group,
    required this.id,
    required this.name,
    required this.path,
    required this.run,
    this.locate,
    this.thumbFile,
    this.icon,
  });

  final PaletteGroup group;
  final String id;
  final String name;
  /// 10px 路径面包屑（「山径破晓 › 画布 02 › 分镜」）。
  final String path;
  /// ↵ 打开。
  final PaletteRun run;
  /// ⌘↵ 在画布中定位；没有的条目（动作）退回 [run]。
  final PaletteRun? locate;
  /// 28×18 缩略图；null 画纯色块。
  final File? thumbFile;
  /// 动作条目的图标（旧面板保留的语义）；镜头 / 产物用缩略图。
  final IconData? icon;
}

/// 面板关闭时的结果：选了哪条、是「打开」还是「定位」。null = 没执行任何动作（Esc / 点外部）。
@immutable
class PaletteChoice {
  const PaletteChoice(this.entry, {this.locate = false});
  final PaletteEntry entry;
  final bool locate;

  PaletteRun get action => locate ? (entry.locate ?? entry.run) : entry.run;
}
