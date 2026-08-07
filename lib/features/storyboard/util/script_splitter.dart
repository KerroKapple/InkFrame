// SB-1 规则脚本拆分器：一段粘贴来的文本 → 一串分镜草稿。
//
// **纯规则，零 LLM**（D-M4-1 拍 A 档）。理由：没有 API key 也能用，行为可断言、
// 可单测、不花钱；而 LLM 辅助拆分的质量无法断言，成本 ≥L，留作日后可选增强。
//
// 纯 Dart，不 import Flutter——拆分是文本处理，与 UI 无关。

/// 一条待落地的分镜草稿。SB-2 把它变成真的 shot 节点。
class ShotDraft {
  const ShotDraft({required this.label, required this.notes});

  /// 节点标题：段首行（已剥编号），超长截断。
  final String label;

  /// 分镜备注：整段原文（已剥段首编号），保留段内换行。
  final String notes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShotDraft && label == other.label && notes == other.notes;

  @override
  int get hashCode => Object.hash(label, notes);

  @override
  String toString() => 'ShotDraft($label)';
}

/// 拆分策略。
enum ScriptSplitStrategy {
  /// 空行分段——一段一镜。适合有段落结构的剧本/大纲。
  blankLine,

  /// 每行一镜。适合已经一行一镜的清单。
  perLine,
}

/// 节点标题的展示上限。超出只截 [label]，[ShotDraft.notes] 永远是全文。
const int kShotLabelMaxLength = 60;

/// 把 [text] 按 [strategy] 拆成分镜草稿。
///
/// 处理顺序：统一换行 → 按策略切块 → 剥段首编号 → 丢弃空块。
/// 结果顺序即输入顺序；空文本得到空清单。
List<ShotDraft> splitScript(
  String text, {
  ScriptSplitStrategy strategy = ScriptSplitStrategy.blankLine,
}) {
  // 统一换行：CRLF / 单独的 CR（老 Mac、某些编辑器）都归一成 LF，
  // 否则 \r 会留在行尾污染 prompt。
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  final blocks = switch (strategy) {
    ScriptSplitStrategy.blankLine => _splitByBlankLine(normalized),
    ScriptSplitStrategy.perLine => normalized.split('\n'),
  };

  final out = <ShotDraft>[];
  for (final block in blocks) {
    final notes = _stripLeadingIndex(_tidy(block));
    if (notes.isEmpty) continue;
    out.add(
      ShotDraft(label: _labelOf(notes), notes: notes),
    );
  }
  return out;
}

/// 按空行切块。「空行」= 只含空白的行，因为从 Word / 网页粘过来的
/// "空行" 常常带着空格或 tab。
List<String> _splitByBlankLine(String text) {
  final blocks = <String>[];
  final buffer = <String>[];
  for (final line in text.split('\n')) {
    if (line.trim().isEmpty) {
      if (buffer.isNotEmpty) {
        blocks.add(buffer.join('\n'));
        buffer.clear();
      }
      continue;
    }
    buffer.add(line);
  }
  if (buffer.isNotEmpty) blocks.add(buffer.join('\n'));
  return blocks;
}

/// 逐行去掉行尾空白（缩进有语义可能是排版，行尾空白纯属噪音），
/// 再去掉整块首尾空白。
String _tidy(String block) =>
    block.split('\n').map((l) => l.trimRight()).join('\n').trim();

/// markdown 标题井号。单独一趟剥——它可以独立出现（`# 山径破晓`），
/// 也可以叠在编号前面（`### Shot 1 dawn`）。
final RegExp _mdHeading = RegExp(r'^\s*#{1,6}\s*');

/// 段首编号前缀。**只匹配行开头**，且要求编号后跟分隔符——
/// 否则 "1920 年代的街道" 会被啃成 "年代的街道"。
///
/// 覆盖：`1.` / `1)` / `1、` / `01．`、中文「镜头N」「第N镜」、
/// 英文 `SHOT N` / `Scene N`（大小写不敏感）。
final RegExp _indexPrefix = RegExp(
  r'^(?:'
  // 镜头 1 / 第 3 镜 / SHOT 1 / Scene 2——这类有明确的词做锚，
  // 分隔符可有可无。
  r'(?:镜头|第)\s*\d+\s*(?:镜)?\s*[:：.．、)）\-—]*\s*'
  r'|(?:shot|scene)\s*\d+\s*[:：.．、)）\-—]*\s*'
  // 光秃秃的数字：**必须**跟分隔符，不然分不清它是编号还是内容。
  r'|\d{1,3}\s*[:：.．、)）\-—]+\s*'
  r')',
  caseSensitive: false,
);

/// 剥掉**段首那一行**的编号；段内后续行原样保留
/// （"2 号机位跟拍" 是内容，不是第 2 镜）。
String _stripLeadingIndex(String block) {
  if (block.isEmpty) return block;
  final lines = block.split('\n');
  lines[0] = lines[0]
      .replaceFirst(_mdHeading, '')
      .replaceFirst(_indexPrefix, '')
      .trim();
  // 首行被剥空时（整行就是个 "1."）丢掉该行，让后续行顶上来。
  if (lines[0].isEmpty) lines.removeAt(0);
  return lines.join('\n').trim();
}

String _labelOf(String notes) {
  final first = notes.split('\n').first.trim();
  return first.length <= kShotLabelMaxLength
      ? first
      : first.substring(0, kShotLabelMaxLength);
}
