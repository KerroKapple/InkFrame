// InkFrame 默认提示音资产的打包守卫：文件在、格式对、时长与电平对，pubspec 声明了目录，
// 播放器引用的就是这一份。
//
// 为什么需要：提示音放不出来只记一条 warn（契约是绝不抛），界面上只是「不响」——analyze
// 与 widget 测全绿，坏资产照样发出去。格式钉的是各平台 media_kit 都能直接放的最保守组合：
// PCM 16-bit 单声道 48 kHz；时长 0.76 s、峰值 −6 dBFS 是 tool/sounds/generate_notification_chime.dart
// 候选 a 的设计值——重新生成换了声音，这里要一起改。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/services/notification_sound/notification_sound_player.dart';

void main() {
  const String assetDir = 'assets/sounds';

  test('播放器引用的资产在 $assetDir/ 下', () {
    expect(kNotificationChimeAsset, '$assetDir/notification.wav');
  });

  test('pubspec.yaml 声明了 $assetDir/ 目录', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('- $assetDir/'),
      isTrue,
      reason: 'pubspec 未声明 $assetDir/ → 打包后没有这个文件，「InkFrame 默认」永远不响',
    );
  });

  test('notification.wav 是 PCM 16-bit 单声道 48 kHz，约 0.76 s，峰值约 −6 dBFS', () {
    final File f = File(kNotificationChimeAsset);
    expect(f.existsSync(), isTrue, reason: '缺资产文件：$kNotificationChimeAsset');

    final Uint8List bytes = f.readAsBytesSync();
    final ByteData b = ByteData.sublistView(bytes);
    String fourcc(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));

    expect(fourcc(0), 'RIFF');
    expect(b.getUint32(4, Endian.little), bytes.length - 8,
        reason: 'RIFF 长度字段与文件大小对不上（截断？）');
    expect(fourcc(8), 'WAVE');

    // 逐块走一遍，不假定 44 字节标准头（别的工具可能塞 LIST 之类的块）。
    int? fmtAt;
    int? dataAt;
    int? dataLength;
    var at = 12;
    while (at + 8 <= bytes.length) {
      final String id = fourcc(at);
      final int length = b.getUint32(at + 4, Endian.little);
      if (id == 'fmt ') fmtAt = at + 8;
      if (id == 'data') {
        dataAt = at + 8;
        dataLength = length;
      }
      at += 8 + length + (length.isOdd ? 1 : 0);
    }
    expect(fmtAt, isNotNull, reason: '没有 fmt 块');
    expect(dataAt, isNotNull, reason: '没有 data 块');

    final int fmt = fmtAt!;
    expect(b.getUint16(fmt, Endian.little), 1, reason: '不是 PCM');
    expect(b.getUint16(fmt + 2, Endian.little), 1, reason: '不是单声道');
    expect(b.getUint32(fmt + 4, Endian.little), 48000, reason: '采样率');
    expect(b.getUint32(fmt + 8, Endian.little), 48000 * 2, reason: '字节率');
    expect(b.getUint16(fmt + 12, Endian.little), 2, reason: '块对齐');
    expect(b.getUint16(fmt + 14, Endian.little), 16, reason: '位深');

    final int data = dataAt!;
    final int samples = dataLength! ~/ 2;
    expect(samples / 48000, closeTo(0.76, 0.01), reason: '时长（秒）');

    var peak = 0;
    for (var i = 0; i < samples; i++) {
      final int v = b.getInt16(data + i * 2, Endian.little).abs();
      if (v > peak) peak = v;
    }
    // −6 dBFS = 半满刻度。太响会吓人，太轻等于没响。
    expect(peak / 32768, closeTo(0.5, 0.02), reason: '峰值电平');
  });
}
