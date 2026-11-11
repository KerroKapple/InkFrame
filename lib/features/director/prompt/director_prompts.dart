// 导演提示词的各段（英文常量，不 i18n——见 docs/CLAUDE.md「LLM / System Prompts」）。
//
// 内容语言只作参数注入（[LanguageSection]），模板本身不随界面语言变化。
// 出图相关的硬规则（不画断肢、画面无文字印章……）留给 A3 往 hard_rules 里加。
import 'prompt_section.dart';

abstract final class DirectorSectionIds {
  static const String role = 'role';
  static const String hardRules = 'hard_rules';
  static const String setting = 'setting';
  static const String language = 'language';
  static const String task = 'task';
}

const String _kRole = '''
You are the director's assistant inside InkFrame, a storyboard and video pre-production tool.
You turn a writer's script into production material that a human director reviews, edits and approves.
Every proposal you make is a draft: the human decides. Be faithful to the source, concrete about what is on screen, and economical with words.''';

const String _kHardRules = '''
- Keep every personal name, place name and named object exactly as written in the script. Never translate, romanize or substitute them.
- Keep the script's era, region and culture. Never move the story to another time or place, and never modernize it.
- Never add characters, objects, events or dialogue that the script does not contain or clearly imply.''';

const PromptSection kDirectorRoleSection = ConstantPromptSection(
  id: DirectorSectionIds.role,
  order: 0,
  stability: PromptStability.stable,
  text: _kRole,
);

const PromptSection kDirectorHardRulesSection = ConstantPromptSection(
  id: DirectorSectionIds.hardRules,
  order: 10,
  stability: PromptStability.stable,
  text: _kHardRules,
);

/// 会话设定。空设定（第一次拆分）⇒ 不出现。
class SettingSection extends PromptSection {
  const SettingSection();

  @override
  String get id => DirectorSectionIds.setting;
  @override
  int get order => 0;
  @override
  PromptStability get stability => PromptStability.session;

  @override
  String render(PromptContext context) {
    final s = context.setting;
    if (s.isEmpty) return '';
    final List<String> lines = <String>[
      'The approved setting of this production (written in the content language). Stay consistent with it.',
      if (s.era.isNotEmpty) 'Era: ${s.era}',
      if (s.region.isNotEmpty) 'Region: ${s.region}',
      if (s.culture.isNotEmpty) 'Culture: ${s.culture}',
      if (s.artStyle.isNotEmpty) 'Art style: ${s.artStyle}',
    ];
    return lines.join('\n');
  }
}

/// 内容语言：已识别 ⇒ 只注入语言码；未识别 ⇒ 让模型自己识别并报回。
class LanguageSection extends PromptSection {
  const LanguageSection();

  @override
  String get id => DirectorSectionIds.language;
  @override
  int get order => 10;
  @override
  PromptStability get stability => PromptStability.session;

  @override
  String render(PromptContext context) {
    final String lang = context.contentLanguage.trim();
    if (lang.isEmpty) {
      return 'Detect the language the script is written in and write every user-facing field in that language. '
          'Report it as a BCP-47 code (for example zh-CN, en-US, ja-JP).';
    }
    return 'Write every user-facing field in $lang.';
  }
}

/// 所有导演步骤共用的段；步骤再追加自己的 task 段。
const List<PromptSection> kDirectorBaseSections = <PromptSection>[
  kDirectorRoleSection,
  kDirectorHardRulesSection,
  SettingSection(),
  LanguageSection(),
];

// ---- 拆分镜（StoryboardStep）----

const String _kStoryboardTask = '''
Break the script into a storyboard: an ordered list of shots that together tell the script from start to end.
For each shot:
- label: a short title for the shot (a few words).
- notes: what the first frame shows (who is where, doing what, in what light), then the action that follows within the shot. Describe only what the camera sees.
- shot_size, camera_angle, camera: pick the value that best serves the moment; use null when no choice clearly fits.
- duration_seconds: a whole number from 1 to 15.
- characters: the names of the characters visible in the shot, spelled exactly as in the script.
Also report content_language and the setting (era, region, culture, art_style) you inferred from the script, written in the content language; use an empty string for anything the script does not establish.
Prefer fewer, well-composed shots over many trivial ones, and keep the script's order.''';

const PromptSection kStoryboardTaskSection = ConstantPromptSection(
  id: DirectorSectionIds.task,
  order: 0,
  stability: PromptStability.step,
  text: _kStoryboardTask,
);

/// user 消息里包剧本的标签（剧本是数据，不是指令）。
const String kScriptOpenTag = '<script>';
const String kScriptCloseTag = '</script>';

/// 驳回意见注入下一次请求时的引导语；意见本身是用户用内容语言写的原文。
const String kRejectionFeedbackIntro =
    'A previous storyboard for this script was rejected by the director. '
    'Address every note below in the new storyboard. Notes, oldest first:';
