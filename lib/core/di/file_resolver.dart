// FileResolverService provider —— app-scoped。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/file_resolver_service.dart';
import 'paths.dart';

final fileResolverServiceProvider = Provider<FileResolverService>(
  (ref) => DefaultFileResolverService(ref.watch(appPathsProvider)),
  name: 'fileResolverServiceProvider',
);
