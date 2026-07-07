// 第三方许可入册回归：验证非 pub 依赖(libmpv/FFmpeg/PostgreSQL/两款字体)
// 经 LicenseRegistry 补入 showLicensePage 的聚合流，且各条目均含非空许可正文。
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(LicenseRegistry.reset);
  tearDown(LicenseRegistry.reset);

  test('注册后 libmpv/FFmpeg/PostgreSQL/两款字体条目均入册', () async {
    registerThirdPartyLicenses();

    final Set<String> packages = <String>{};
    await for (final LicenseEntry entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
    }

    expect(
      packages,
      containsAll(<String>[
        'libmpv',
        'FFmpeg',
        'PostgreSQL',
        'Cormorant Garamond (font)',
        'JetBrains Mono (font)',
      ]),
    );
  });

  test('每个第三方条目含非空许可正文', () async {
    registerThirdPartyLicenses();

    var count = 0;
    await for (final LicenseEntry entry in LicenseRegistry.licenses) {
      count++;
      final String text =
          entry.paragraphs.map((LicenseParagraph p) => p.text).join('\n');
      expect(text.trim(), isNotEmpty, reason: '${entry.packages} 许可正文为空');
    }
    expect(count, greaterThanOrEqualTo(4));
  });
}
