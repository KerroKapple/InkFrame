// UpdateCheckResult 值语义测试（UPD-1）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/update_check_result.dart';

void main() {
  test('latestVersion 非空即视为有更新', () {
    const upToDate = UpdateCheckResult(currentVersion: '0.1.0-alpha.10');
    expect(upToDate.updateAvailable, isFalse);

    const available = UpdateCheckResult(
      currentVersion: '0.1.0-alpha.10',
      latestVersion: '0.1.0-alpha.11',
      releaseUrl: 'https://github.com/KerroKapple/InkFrame/releases/tag/v0.1.0-alpha.11',
    );
    expect(available.updateAvailable, isTrue);
  });

  test('== 与 hashCode 值语义', () {
    const a = UpdateCheckResult(
      currentVersion: '0.1.0-alpha.10',
      latestVersion: '0.1.0-alpha.11',
      releaseUrl: 'https://example.com',
    );
    const b = UpdateCheckResult(
      currentVersion: '0.1.0-alpha.10',
      latestVersion: '0.1.0-alpha.11',
      releaseUrl: 'https://example.com',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const UpdateCheckResult(currentVersion: '0.1.0-alpha.10')));
  });
}
