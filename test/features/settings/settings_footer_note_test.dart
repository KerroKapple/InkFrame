// 底部条文案按页分三种：写钥匙串 / 即时生效 / 只读。
//
// 这条测试存在的理由：P7 补了三个只读页，而底部条原来是一句全局的
// 「改动即时生效并写入钥匙串」——挂在只读页底下是假话。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/settings/providers/settings_page.dart';
import 'package:inkframe/features/settings/util/settings_footer_note.dart';

void main() {
  test('只有 API 密钥页说「写入钥匙串」', () {
    for (final SettingsPage p in SettingsPage.values) {
      final bool saysKeychain =
          footerNoteKindOf(p) == SettingsFooterNoteKind.keychain;
      expect(
        saysKeychain,
        p == SettingsPage.apiKeys,
        reason: '$p 不该/该说钥匙串',
      );
    }
  });

  test('三个只读页与关于页都归只读口径', () {
    for (final SettingsPage p in <SettingsPage>[
      SettingsPage.shortcuts,
      SettingsPage.performance,
      SettingsPage.network,
      SettingsPage.about,
    ]) {
      expect(footerNoteKindOf(p), SettingsFooterNoteKind.readOnly, reason: '$p');
    }
  });

  test('可改的页说「即时生效」', () {
    for (final SettingsPage p in <SettingsPage>[
      SettingsPage.general,
      SettingsPage.nodeLayout,
      SettingsPage.storage,
    ]) {
      expect(footerNoteKindOf(p), SettingsFooterNoteKind.live, reason: '$p');
    }
  });

  test('每一页都被认领——新增页不给口径就红', () {
    // switch 是穷尽的，少一页编译期就过不去；这条守的是「将来有人补了页
    // 却顺手塞进 default」的情况。
    for (final SettingsPage p in SettingsPage.values) {
      expect(() => footerNoteKindOf(p), returnsNormally, reason: '$p');
    }
  });
}
