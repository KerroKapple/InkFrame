// 诊断包 DI（LB-18）：纯装配。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/diagnostics_bundle_service.dart';
import '../interfaces/diagnostics_bundle_service.dart';
import 'clock.dart';
import 'logger.dart';
import 'package_info.dart';
import 'paths.dart';

final diagnosticsBundleServiceProvider =
    FutureProvider<DiagnosticsBundleService>((ref) async {
  final info = await ref.watch(packageInfoProvider.future);
  return ZipDiagnosticsBundleService(
    paths: ref.watch(appPathsProvider),
    clock: ref.watch(clockProvider),
    appVersion: info.version,
    logger: ref.watch(loggerProvider),
  );
}, name: 'diagnosticsBundleServiceProvider');
