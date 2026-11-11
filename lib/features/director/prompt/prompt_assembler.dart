// 把各段拼成一份 system 提示词：先按 stability（stable → session → step），再按 order，
// 同序按 id——结果与传入顺序无关，同样的段 + 同样的上下文永远拼出同一串字节。
// 每段包进 <id>…</id>，空段跳过。拼出来的整串原样进 model_request 的请求体。
import 'prompt_section.dart';

class PromptAssembler {
  const PromptAssembler();

  String assemble(Iterable<PromptSection> sections, PromptContext context) {
    final List<PromptSection> sorted = sections.toList()
      ..sort((PromptSection a, PromptSection b) {
        final int s = a.stability.index.compareTo(b.stability.index);
        if (s != 0) return s;
        final int o = a.order.compareTo(b.order);
        return o != 0 ? o : a.id.compareTo(b.id);
      });
    final List<String> parts = <String>[];
    for (final PromptSection s in sorted) {
      final String body = s.render(context).trim();
      if (body.isEmpty) continue;
      parts.add('<${s.id}>\n$body\n</${s.id}>');
    }
    return parts.join('\n\n');
  }
}
