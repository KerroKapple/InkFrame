// 第三方许可补册：showLicensePage 只自动聚合 pub 包内的 LICENSE 文件，
// 随发布一起分发的原生二进制与打包字体不在其中，必须经 LicenseRegistry 手动入册，
// 才能在关于页许可列表中呈现并满足署名/许可义务。
//
// 覆盖对象：
//   - libmpv + FFmpeg：media_kit_libs_video 分发的 LGPL-2.1「video」构建（动态链接）
//   - PostgreSQL：内嵌数据库二进制（PostgreSQL License）
//   - Cormorant Garamond / JetBrains Mono：打包字体（SIL OFL 1.1）
//
// 许可正文以 assets 为单一事实源（assets/licenses、assets/fonts），此处按需加载后入册；
// 说明性 notice 属法律署名文本，保持英文常量（非 ARB 用户文案）。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

const String _kLibmpvFfmpegNotice = '''
InkFrame bundles the libmpv and FFmpeg shared libraries via package:media_kit
(media_kit_libs_video). These are the LGPL-2.1 "video" builds produced by the
media-kit project (FFmpeg configured without --enable-gpl / --enable-nonfree;
mpv built with -Dgpl=false):

  - Windows: github.com/media-kit/libmpv-win32-video-build
  - macOS:   github.com/media-kit/libmpv-darwin-build (video-default flavor)

The libraries are dynamically linked. Under LGPL-2.1 you may replace them with a
modified version; their corresponding source is available from the upstream
build repositories above and from ffmpeg.org and github.com/mpv-player/mpv.

The full text of the GNU Lesser General Public License, version 2.1, follows.
''';

/// 把非 pub 依赖的许可条目补进 `LicenseRegistry`，供 `showLicensePage` 聚合展示。
/// 在 `main()` 绑定初始化后调用一次。
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    final String lgpl =
        await rootBundle.loadString('assets/licenses/LGPL-2.1.txt');
    yield LicenseEntryWithLineBreaks(
      const <String>['libmpv', 'FFmpeg'],
      '$_kLibmpvFfmpegNotice\n$lgpl',
    );
  });

  LicenseRegistry.addLicense(() async* {
    final String pg =
        await rootBundle.loadString('assets/licenses/PostgreSQL.txt');
    yield LicenseEntryWithLineBreaks(const <String>['PostgreSQL'], pg);
  });

  LicenseRegistry.addLicense(() async* {
    final String ofl =
        await rootBundle.loadString('assets/fonts/OFL-CormorantGaramond.txt');
    yield LicenseEntryWithLineBreaks(
      const <String>['Cormorant Garamond (font)'],
      ofl,
    );
  });

  LicenseRegistry.addLicense(() async* {
    final String ofl =
        await rootBundle.loadString('assets/fonts/OFL-JetBrainsMono.txt');
    yield LicenseEntryWithLineBreaks(
      const <String>['JetBrains Mono (font)'],
      ofl,
    );
  });
}
