// 分段拼装：排序与传入顺序无关、稳定段在前、语言只作参数注入、稳定前缀逐字节一致。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/director.dart';
import 'package:inkframe/features/director/prompt/director_prompts.dart';
import 'package:inkframe/features/director/prompt/prompt_assembler.dart';
import 'package:inkframe/features/director/prompt/prompt_section.dart';

PromptSection _c(String id, int order, PromptStability s) =>
    ConstantPromptSection(id: id, order: order, stability: s, text: id);

void main() {
  const PromptAssembler assembler = PromptAssembler();
  const PromptContext empty =
      PromptContext(contentLanguage: '', setting: DirectorSetting.empty);

  test('先按 stability 再按 order，同序按 id；与传入顺序无关', () {
    final List<PromptSection> sections = <PromptSection>[
      _c('task', 0, PromptStability.step),
      _c('b', 5, PromptStability.session),
      _c('z', 1, PromptStability.stable),
      _c('a', 5, PromptStability.session),
      _c('y', 0, PromptStability.stable),
    ];
    final String forward = assembler.assemble(sections, empty);
    final String backward = assembler.assemble(sections.reversed, empty);
    expect(forward, backward);
    final List<String> order = RegExp(r'^<(\w+)>$', multiLine: true)
        .allMatches(forward)
        .map((RegExpMatch m) => m.group(1)!)
        .toList();
    expect(order, <String>['y', 'z', 'a', 'b', 'task']);
  });

  test('空段跳过；每段包进同名标签', () {
    final String s = assembler.assemble(<PromptSection>[
      _c('role', 0, PromptStability.stable),
      const SettingSection(),
    ], empty);
    expect(s, '<role>\nrole\n</role>');
  });

  test('语言段：已识别只注入语言码；未识别让模型自己识别', () {
    const PromptContext zh =
        PromptContext(contentLanguage: 'zh-CN', setting: DirectorSetting.empty);
    expect(const LanguageSection().render(zh), 'Write every user-facing field in zh-CN.');
    expect(const LanguageSection().render(empty), contains('BCP-47'));
  });

  test('设定段：有值才出现，值原样（内容语言）', () {
    const PromptContext ctx = PromptContext(
      contentLanguage: 'zh-CN',
      setting: DirectorSetting(era: '唐', artStyle: '水墨'),
    );
    final String s = const SettingSection().render(ctx);
    expect(s, contains('Era: 唐'));
    expect(s, contains('Art style: 水墨'));
    expect(s, isNot(contains('Region:')));
  });

  test('同一会话两次拼装逐字节一致；不同会话的稳定前缀逐字节一致', () {
    const PromptContext a =
        PromptContext(contentLanguage: 'zh-CN', setting: DirectorSetting(era: '唐'));
    const PromptContext b =
        PromptContext(contentLanguage: 'en-US', setting: DirectorSetting.empty);
    final List<PromptSection> sections = <PromptSection>[
      ...kDirectorBaseSections,
      kStoryboardTaskSection,
    ];
    expect(assembler.assemble(sections, a), assembler.assemble(sections, a));

    final String stablePrefix = assembler.assemble(
      sections.where((PromptSection s) => s.stability == PromptStability.stable),
      empty,
    );
    expect(assembler.assemble(sections, a), startsWith(stablePrefix));
    expect(assembler.assemble(sections, b), startsWith(stablePrefix));
  });

  test('模板与界面语言无关：提示词常量全是 ASCII 英文', () {
    final String s = assembler.assemble(<PromptSection>[
      ...kDirectorBaseSections,
      kStoryboardTaskSection,
    ], const PromptContext(contentLanguage: 'en-US', setting: DirectorSetting.empty));
    expect(RegExp(r'^[\x00-\x7F]*$').hasMatch(s), isTrue);
  });
}
