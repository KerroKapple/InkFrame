// 时间码（Timeline 稿）：监视器 / 状态栏用完整 HH:MM:SS:FF，叙事链列表用短格式 MM:SS（帧位保留）。
// 帧率没有字段（PLAN 不做清单 / P3 也不补），按稿的 24fps 换算帧位。
const int kSequenceFps = 24;

String _two(int v) => v.toString().padLeft(2, '0');

/// HH:MM:SS:FF。
String formatTimecode(int ms) {
  final int clamped = ms < 0 ? 0 : ms;
  final int totalSeconds = clamped ~/ 1000;
  final int frames = ((clamped % 1000) * kSequenceFps / 1000).floor();
  final int h = totalSeconds ~/ 3600;
  final int m = (totalSeconds % 3600) ~/ 60;
  final int s = totalSeconds % 60;
  return '${_two(h)}:${_two(m)}:${_two(s)}:${_two(frames)}';
}

/// 稿的列表短格式：SS:FF（不带恒为 00 的小时位；超过一分钟时前面带分位 MM:SS:FF）。
String formatTimecodeShort(int ms) {
  final int clamped = ms < 0 ? 0 : ms;
  final int totalSeconds = clamped ~/ 1000;
  final int frames = ((clamped % 1000) * kSequenceFps / 1000).floor();
  final int m = totalSeconds ~/ 60;
  final int s = totalSeconds % 60;
  return m > 0 ? '${_two(m)}:${_two(s)}:${_two(frames)}' : '${_two(s)}:${_two(frames)}';
}
