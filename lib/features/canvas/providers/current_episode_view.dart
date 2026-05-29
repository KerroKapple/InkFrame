// currentEpisodeViewProvider — Canvas/Episode 工作区当前展示的视图。
// 顺序对齐 mockup _components.js 的 EPISODE_VIEWS。
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EpisodeView { canvas, storyboard, script, generation, queue }

final currentEpisodeViewProvider = StateProvider<EpisodeView>(
  (ref) => EpisodeView.canvas,
  name: 'currentEpisodeViewProvider',
);
