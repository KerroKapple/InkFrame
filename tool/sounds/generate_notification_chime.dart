// InkFrame 通知提示音生成器：纯数学合成，不含任何第三方音频素材。
//
// 用法（在仓库根目录下运行）：
//   dart run tool/sounds/generate_notification_chime.dart
//       重新生成 assets/sounds/notification.wav（候选 a，打包进应用的那一份）。
//   dart run tool/sounds/generate_notification_chime.dart --candidates [目录]
//       把 a / b / c 三个候选写成 <目录>/chime_a.wav、chime_b.wav、chime_c.wav
//       （目录缺省为当前目录），给设计评审对比试听；不碰 assets/。
//
// 输出是确定性的：同一份代码跑出来的 notification.wav 逐字节相同。改任何常数或运算
// 顺序都会让资产变——test/services/notification_sound/notification_chime_asset_test.dart
// 钉了格式（PCM 16-bit 单声道 48 kHz）、时长与峰值电平；真要换声音，重新生成后一起改测试。
//
// 三个候选：
//   a = 双音上行（F5 → C6，纯五度）——默认；短、软、往上走，读作「好了」
//   b = 单音气泡（740 → 988 Hz 滑音）——最短、最轻
//   c = 三音琶音（G5 B5 D6）——最「亮」，偏成就感
//
// 音色是 FM 槌击：起音瞬间调制指数高、30ms 内衰减到近乎纯正弦，
// 听感接近木琴 / 钢片琴的「叮」，没有尖锐的高频残留。
//
// 后期链：各音符相加 → 极简 Schroeder 混响（一点空间感，不拖尾）→ 尾部 60 ms 余弦淡出
// （防截断爆音）→ 峰值归一到 −6 dBFS（系统通知音的常见电平）→ 16-bit PCM WAV。
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// 采样率（Hz）。
const int kRate = 48000;

/// 一个音符。时间都以毫秒计。
class Note {
  const Note(this.startMs, this.freq, this.amp, this.decayMs,
      {this.glideFromHz, this.glideMs = 0});

  /// 相对整段开头的起音时刻。
  final double startMs;

  /// 稳定后的频率（Hz）。
  final double freq;

  /// 相对响度（各音符之间的比例；最后整体归一）。
  final double amp;

  /// 指数衰减的时间常数。
  final double decayMs;

  /// 滑音起点频率；null = 不滑。
  final double? glideFromHz;

  /// 滑音时长：从 [glideFromHz] 线性变到 [freq]。
  final double glideMs;
}

/// 一个候选提示音：名字、总长、音符表。
class Chime {
  const Chime(this.name, this.lengthMs, this.notes);
  final String name;
  final double lengthMs;
  final List<Note> notes;
}

/// 三个候选；第一个（a）是打包进应用的那一份。
const List<Chime> kChimes = <Chime>[
  Chime('a', 760, <Note>[
    Note(0, 698.46, 0.78, 150),
    Note(82, 1046.50, 1.0, 270),
  ]),
  Chime('b', 620, <Note>[
    Note(0, 987.77, 1.0, 175, glideFromHz: 740.0, glideMs: 28),
  ]),
  Chime('c', 820, <Note>[
    Note(0, 783.99, 0.72, 160),
    Note(58, 987.77, 0.82, 180),
    Note(116, 1174.66, 1.0, 290),
  ]),
];

/// 打包进应用的资产路径（相对仓库根）。
const String kAssetPath = 'assets/sounds/notification.wav';

double _phase(Note n, double t) {
  // 相位 = 2π ∫ f(t) dt；滑音段线性变频，之后恒定。
  final g = n.glideFromHz;
  if (g == null || n.glideMs <= 0) return 2 * math.pi * n.freq * t;
  final tg = n.glideMs / 1000;
  if (t < tg) {
    final k = (n.freq - g) / tg;
    return 2 * math.pi * (g * t + 0.5 * k * t * t);
  }
  final atGlideEnd = 2 * math.pi * (g * tg + 0.5 * (n.freq - g) * tg);
  return atGlideEnd + 2 * math.pi * n.freq * (t - tg);
}

/// 一个音符在绝对时刻 [tAbs]（秒）的采样值：3 ms 正弦平方起音 + 指数衰减包络，
/// FM 槌击（调制指数 1.35、28 ms 衰减），外加一丝 2.76 倍频的「叮」（35 ms 衰减）。
double _voice(Note n, double tAbs) {
  final t = tAbs - n.startMs / 1000;
  if (t < 0) return 0;
  const attack = 0.003;
  final double env = t < attack
      ? math.pow(math.sin(math.pi / 2 * t / attack), 2).toDouble()
      : math.exp(-(t - attack) / (n.decayMs / 1000));
  final idx = 1.35 * math.exp(-t / 0.028);
  final ph = _phase(n, t);
  final body = math.sin(ph + idx * math.sin(ph));
  final ping = 0.07 * math.exp(-t / 0.035) * math.sin(ph * 2.76);
  return n.amp * env * (body + ping);
}

/// 极简 Schroeder 混响：四路并联梳状（反馈里带一阶低通）+ 两级全通。
List<double> _reverb(List<double> dry, {double wet = 0.14}) {
  final combDelays = <int>[1427, 1781, 1973, 2099]; // ≈ 29.7 / 37.1 / 41.1 / 43.7 ms
  const fb = 0.62, damp = 0.35;
  final out = List<double>.filled(dry.length, 0);
  for (final d in combDelays) {
    final buf = List<double>.filled(d, 0);
    var idx = 0;
    var lp = 0.0;
    for (var i = 0; i < dry.length; i++) {
      final y = buf[idx];
      lp = y * (1 - damp) + lp * damp;
      buf[idx] = dry[i] + lp * fb;
      idx = (idx + 1) % d;
      out[i] += y / combDelays.length;
    }
  }
  for (final d in <int>[241, 83]) {
    final buf = List<double>.filled(d, 0);
    var idx = 0;
    const g = 0.5;
    for (var i = 0; i < out.length; i++) {
      final bufOut = buf[idx];
      final x = out[i];
      final y = -x + bufOut;
      buf[idx] = x + bufOut * g;
      idx = (idx + 1) % d;
      out[i] = y;
    }
  }
  return <double>[for (var i = 0; i < dry.length; i++) dry[i] + wet * out[i]];
}

/// 整段合成：音符相加 → 混响 → 尾部淡出 → 峰值归一到 [_kPeakTarget]。
List<double> _render(Chime c) {
  final n = (c.lengthMs / 1000 * kRate).round();
  var s = <double>[
    for (var i = 0; i < n; i++)
      c.notes.fold<double>(0, (a, note) => a + _voice(note, i / kRate)),
  ];
  s = _reverb(s);
  // 尾部 60ms 余弦淡出，防截断爆音
  final fade = (0.060 * kRate).round();
  for (var i = 0; i < fade; i++) {
    final k = 0.5 * (1 + math.cos(math.pi * i / fade));
    s[n - fade + i] *= k;
  }
  final peak = s.fold<double>(0, (m, v) => math.max(m, v.abs()));
  const target = _kPeakTarget;
  return <double>[for (final v in s) v / peak * target];
}

/// 归一后的峰值：0.5 = −6 dBFS——系统通知音的常见电平，避免吓人。
const double _kPeakTarget = 0.5;

/// 16-bit PCM 单声道 WAV（44 字节标准头）。
Uint8List _wav(List<double> s) {
  final data = ByteData(s.length * 2);
  for (var i = 0; i < s.length; i++) {
    final v = (s[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(i * 2, v, Endian.little);
  }
  final h = ByteData(44);
  void tag(int o, String t) {
    for (var i = 0; i < 4; i++) {
      h.setUint8(o + i, t.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  h.setUint32(4, 36 + s.length * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  h.setUint32(16, 16, Endian.little);
  h.setUint16(20, 1, Endian.little); // PCM
  h.setUint16(22, 1, Endian.little); // mono
  h.setUint32(24, kRate, Endian.little);
  h.setUint32(28, kRate * 2, Endian.little);
  h.setUint16(32, 2, Endian.little);
  h.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  h.setUint32(40, s.length * 2, Endian.little);
  return Uint8List.fromList(<int>[
    ...h.buffer.asUint8List(),
    ...data.buffer.asUint8List(),
  ]);
}

/// 渲染一个候选并写到 [path]，打印采样数与 RMS 电平。
void _write(Chime c, String path) {
  final s = _render(c);
  var sq = 0.0;
  for (final v in s) {
    sq += v * v;
  }
  final rms = math.sqrt(sq / s.length);
  File(path).writeAsBytesSync(_wav(s));
  stdout.writeln('${c.name} -> $path: ${s.length} samples, '
      'peak=$_kPeakTarget, '
      'rms=${(20 * math.log(rms) / math.ln10).toStringAsFixed(1)} dBFS');
}

void main(List<String> args) {
  if (args.isNotEmpty && args.first == '--candidates') {
    final String outDir = args.length > 1 ? args[1] : '.';
    Directory(outDir).createSync(recursive: true);
    for (final c in kChimes) {
      _write(c, '$outDir/chime_${c.name}.wav');
    }
    return;
  }
  if (args.isNotEmpty) {
    stderr.writeln('usage: dart run tool/sounds/generate_notification_chime.dart '
        '[--candidates [dir]]');
    exitCode = 64;
    return;
  }
  // 默认：重新生成打包资产。资产路径相对仓库根，不在根目录下跑就别写到奇怪的地方去。
  if (!File('pubspec.yaml').existsSync() ||
      !Directory('assets/sounds').existsSync()) {
    stderr.writeln('run from the repository root (pubspec.yaml and '
        'assets/sounds/ must exist)');
    exitCode = 66;
    return;
  }
  _write(kChimes.first, kAssetPath);
}
