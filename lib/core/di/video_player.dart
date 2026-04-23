// VideoPlayerService 的 Riverpod DI。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/video_player_service.dart';
import '../../services/media_kit_video_player_service.dart';

final videoPlayerServiceProvider = Provider<VideoPlayerService>(
  (ref) => MediaKitVideoPlayerService(),
);
