// AboutSection widget test — 探测可用 / 不可用两条路径。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/features/settings/widgets/about_section.dart';

import '../../_harness/test_app.dart';

class _OkSecure implements SecureStorageService {
  final Map<String, String> _data = {};
  @override
  Future<void> store(String k, String v) async => _data[k] = v;
  @override
  Future<String?> retrieve(String k) async => _data[k];
  @override
  Future<void> delete(String k) async => _data.remove(k);
  @override
  Future<bool> exists(String k) async => _data.containsKey(k);
}

class _BrokenSecure implements SecureStorageService {
  @override
  Future<void> store(String k, String v) async => throw StateError('boom');
  @override
  Future<String?> retrieve(String k) async => null;
  @override
  Future<void> delete(String k) async {}
  @override
  Future<bool> exists(String k) async => false;
}

void main() {
  testWidgets('探测成功显示 Available', (tester) async {
    await pumpInkApp(
      tester,
      const SingleChildScrollView(child: AboutSection()),
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_OkSecure()),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Available'), findsOneWidget);
  });

  testWidgets('探测抛错显示 Unavailable + 原因', (tester) async {
    await pumpInkApp(
      tester,
      const SingleChildScrollView(child: AboutSection()),
      overrides: [
        secureStorageServiceProvider.overrideWithValue(_BrokenSecure()),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unavailable'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });
}
