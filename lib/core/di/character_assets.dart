// 角色参考图资产服务 DI。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/character_asset_service.dart';
import '../../services/character_asset_service.dart';
import 'paths.dart';

final characterAssetServiceProvider = Provider<CharacterAssetService>(
  (ref) => DefaultCharacterAssetService(ref.watch(appPathsProvider)),
  name: 'characterAssetServiceProvider',
);
