// PRD §7.4 唯一拼接公式：base前缀 + 泳道风格 + 关联文本 + 用户prompt + base后缀。
// 段间 ", "（上段以标点结尾则只空格）；空段跳过；ignoreLaneStyle 时泳道段为空。
String assemblePrompt({
  String baseStylePrefix = '',
  String laneStylePrompt = '',
  List<String> associatedTexts = const [],
  required String userPrompt,
  String baseStyleSuffix = '',
  bool ignoreLaneStyle = false,
}) {
  final segments = <String>[
    baseStylePrefix,
    if (!ignoreLaneStyle) laneStylePrompt,
    ...associatedTexts,
    userPrompt,
    baseStyleSuffix,
  ];
  final parts = [for (final s in segments) if (s.trim().isNotEmpty) s.trim()];
  if (parts.isEmpty) return '';
  final buf = StringBuffer(parts.first);
  for (var i = 1; i < parts.length; i++) {
    buf.write(_endsWithPunct(parts[i - 1]) ? ' ' : ', ');
    buf.write(parts[i]);
  }
  return buf.toString();
}

const _kPunct = {',', '.', ';', '!', '?', '，', '。', '；', '！', '？', '、'};
bool _endsWithPunct(String s) => s.isNotEmpty && _kPunct.contains(s[s.length - 1]);
