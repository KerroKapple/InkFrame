// 设置浮层底部条那句话该说什么——按当前页分三种，纯函数。
//
// 为什么需要它：底部条原来是**一句全局文案**「改动即时生效并写入钥匙串」，
// 那是为「API 密钥」页写的。P7 补上快捷键 / 性能 / 网络三个只读页之后，这句话
// 挂在它们底下就成了假话——那三页一个字都不写，更不碰钥匙串。
// 底部条是壳的一部分（与回收站浮层共用），不该认识具体页，所以判定收在这里。
import '../providers/settings_page.dart';

/// 底部条文案的三种口径。
enum SettingsFooterNoteKind {
  /// 写系统钥匙串（只有「API 密钥」页）。
  keychain,

  /// 改动即时生效、落本地配置（常规 / 节点布局 / 存储）。
  live,

  /// 本页只读，什么都不写（快捷键 / 性能 / 网络 / 关于）。
  readOnly,
}

/// 当前页决定底部条说哪一句。
SettingsFooterNoteKind footerNoteKindOf(SettingsPage page) => switch (page) {
      SettingsPage.apiKeys => SettingsFooterNoteKind.keychain,
      SettingsPage.shortcuts ||
      SettingsPage.performance ||
      SettingsPage.network ||
      SettingsPage.about =>
        SettingsFooterNoteKind.readOnly,
      SettingsPage.general ||
      SettingsPage.nodeLayout ||
      SettingsPage.storage =>
        SettingsFooterNoteKind.live,
    };
