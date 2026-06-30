// preferencesServiceProvider：默认 InMemory（测试/无持久化即可用）；
// main 启动时用 FilePreferencesService 覆盖并预加载（见 lib/main.dart）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/file_preferences_service.dart';
import '../interfaces/preferences_service.dart';

final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => InMemoryPreferencesService(),
  name: 'preferencesServiceProvider',
);
