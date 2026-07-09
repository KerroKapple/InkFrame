// UrlOpenerService 的 Riverpod DI —— app-scoped,复用 ProcessRunner。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/process_url_opener_service.dart';
import '../interfaces/url_opener_service.dart';
import 'process_runner.dart';

final urlOpenerServiceProvider = Provider<UrlOpenerService>(
  (ref) => ProcessUrlOpenerService(runner: ref.watch(processRunnerProvider)),
  name: 'urlOpenerServiceProvider',
);
