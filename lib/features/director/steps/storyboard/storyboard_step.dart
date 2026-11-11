// 第一个导演步骤：剧本 → 分镜表（结构化输出 output_config.format）→ 画布上的镜头链。
//
// 解析宽容：未知枚举当 null、时长夹到 1–15 秒、空标题取备注首行、出场角色名附在备注末行
// （挂角色库留到 A3）。一次拆分只调一次模型，effort medium，不做 caching / batches。
import 'dart:convert';

import '../../../../core/constants/director_keys.dart';
import '../../../../core/errors/ink_error.dart';
import '../../../../core/models/claude_message.dart';
import '../../../../core/models/director.dart';
import '../../../../core/models/provider_capabilities.dart';
import '../../../../core/models/shot_language.dart';
import '../../../storyboard/models/shot_draft.dart';
import '../../../storyboard/util/script_splitter.dart';
import '../../log/director_log.dart';
import '../../log/director_payloads.dart';
import '../../pipeline/director_step.dart';
import '../../prompt/director_prompts.dart';
import '../../prompt/prompt_assembler.dart';
import '../../prompt/prompt_section.dart';
import 'storyboard_proposal.dart';

/// 时长夹取范围与缺省（秒）。
const int kStoryboardMinSeconds = 1;
const int kStoryboardMaxSeconds = 15;
const int kStoryboardDefaultSeconds = 3;

/// 出场角色名在备注末行的分隔符（中性符号，不随语言变）。
const String kCharacterSeparator = ' · ';

/// content_language 落库上限（与 director_sessions 的 CHECK 同值）。
const int kContentLanguageMaxLength = 35;

/// 结构化输出的顶层键。
abstract final class StoryboardSchemaKeys {
  static const String contentLanguage = 'content_language';
  static const String setting = 'setting';
  static const String shots = 'shots';
}

const String _kStepId = 'storyboard';

class StoryboardStep extends DirectorStep<StoryboardProposal> {
  const StoryboardStep({this.assembler = const PromptAssembler()});

  final PromptAssembler assembler;

  @override
  String get id => _kStepId;

  @override
  DirectorEventKind get proposedKind => DirectorEventKind.storyboardProposed;

  List<PromptSection> get sections =>
      const <PromptSection>[...kDirectorBaseSections, kStoryboardTaskSection];

  @override
  ClaudeRequest buildRequest({
    required DirectorSession session,
    required DirectorLog log,
    required int inputSeq,
  }) {
    final DirectorEvent? input = log[inputSeq];
    if (input == null || input.kind != DirectorEventKind.scriptSubmitted) {
      throw const ProviderError(
        code: InkErrorCode.invalidParameter,
        extra: <String, Object?>{'reason': 'storyboard_input_missing'},
      );
    }
    final ({String text, List<String> feedback}) script = scriptOf(input);
    return ClaudeRequest(
      system: assembler.assemble(sections, PromptContext.of(session)),
      messages: <ClaudeMessageParam>[
        ClaudeMessageParam(
          role: ClaudeRole.user,
          content: <ClaudeContentBlock>[
            ClaudeTextBlock('$kScriptOpenTag\n${script.text}\n$kScriptCloseTag'),
            if (script.feedback.isNotEmpty)
              ClaudeTextBlock(<String>[
                kRejectionFeedbackIntro,
                for (final String f in script.feedback) '- $f',
              ].join('\n')),
          ],
        ),
      ],
      effort: ClaudeEffort.medium,
      outputSchema: kStoryboardSchema,
    );
  }

  @override
  StoryboardProposal parse(ClaudeMessage message) {
    final Object? decoded;
    try {
      decoded = jsonDecode(message.text);
    } on FormatException catch (e) {
      throw ProviderError(
        code: InkErrorCode.providerInvalidResponse,
        extra: const <String, Object?>{'reason': 'storyboard_not_json'},
        cause: e,
      );
    }
    if (decoded is! Map) throw _invalid('storyboard_not_object');
    final Object? rawShots = decoded[StoryboardSchemaKeys.shots];
    final List<StoryboardShot> shots = <StoryboardShot>[
      if (rawShots is List)
        for (final Object? s in rawShots)
          if (s is Map) ?_shotOf(s),
    ];
    if (shots.isEmpty) throw _invalid('storyboard_empty');
    final Object? lang = decoded[StoryboardSchemaKeys.contentLanguage];
    final String language = lang is String ? lang.trim() : '';
    return StoryboardProposal(
      contentLanguage: language.length > kContentLanguageMaxLength
          ? language.substring(0, kContentLanguageMaxLength)
          : language,
      setting: DirectorSetting.fromJson(decoded[StoryboardSchemaKeys.setting]),
      shots: shots,
    );
  }

  @override
  Map<String, Object?> encodeProposal(StoryboardProposal proposal) =>
      <String, Object?>{...proposal.toJson(), DirectorPayloadKeys.step: _kStepId};

  @override
  StoryboardProposal decodeProposal(Map<String, Object?> payload) =>
      StoryboardProposal.fromJson(payload);

  @override
  DirectorSessionPatch sessionPatchOf(StoryboardProposal p) => (
        contentLanguage: p.contentLanguage.isEmpty ? null : p.contentLanguage,
        setting: p.setting.isEmpty ? null : p.setting,
      );

  @override
  Future<List<String>> apply(StoryboardProposal proposal, ShotChainWriter writer) =>
      writer.writeShotChain(<ShotDraft>[
        for (final StoryboardShot s in proposal.shots)
          ShotDraft(
            label: s.label,
            notes: s.notes,
            shotSize: s.shotSize,
            cameraAngle: s.cameraAngle,
            camera: s.camera,
            durationMs: s.durationMs,
          ),
      ]);
}

StoryboardShot? _shotOf(Map<Object?, Object?> raw) {
  String str(String k) {
    final Object? v = raw[k];
    return v is String ? v.trim() : '';
  }

  final Object? rawChars = raw[StoryboardKeys.characters];
  final List<String> characters = <String>[
    ...<String>{
      if (rawChars is List)
        for (final Object? c in rawChars)
          if (c is String && c.trim().isNotEmpty) c.trim(),
    },
  ];
  final String body = str(StoryboardKeys.notes);
  final String notes = <String>[
    if (body.isNotEmpty) body,
    if (characters.isNotEmpty) characters.join(kCharacterSeparator),
  ].join('\n');
  String label = str(StoryboardKeys.label);
  if (label.isEmpty) label = notes.split('\n').first.trim();
  if (label.isEmpty && notes.isEmpty) return null;
  if (label.length > kShotLabelMaxLength) label = label.substring(0, kShotLabelMaxLength);

  final Object? seconds = raw[StoryboardKeys.durationSeconds];
  final int clamped = seconds is num
      ? seconds.round().clamp(kStoryboardMinSeconds, kStoryboardMaxSeconds)
      : kStoryboardDefaultSeconds;
  return StoryboardShot(
    label: label,
    notes: notes,
    shotSize: enumByName(ShotSize.values, raw[StoryboardKeys.shotSize]),
    cameraAngle: enumByName(CameraAngle.values, raw[StoryboardKeys.cameraAngle]),
    camera: enumByName(CameraMovement.values, raw[StoryboardKeys.camera]),
    durationMs: clamped * 1000,
    characters: characters,
  );
}

ProviderError _invalid(String reason) => ProviderError(
      code: InkErrorCode.providerInvalidResponse,
      extra: <String, Object?>{'reason': reason},
    );

Map<String, Object?> _nullableEnum(List<Enum> values) => <String, Object?>{
      'anyOf': <Object?>[
        <String, Object?>{
          'type': 'string',
          'enum': <String>[for (final Enum v in values) v.name],
        },
        <String, Object?>{'type': 'null'},
      ],
    };

Map<String, Object?> _object(Map<String, Object?> properties) => <String, Object?>{
      'type': 'object',
      'properties': properties,
      'required': properties.keys.toList(),
      'additionalProperties': false,
    };

const Map<String, Object?> _kString = <String, Object?>{'type': 'string'};

/// 分镜表的 JSON Schema。枚举直接是 ShotSize / CameraAngle / CameraMovement 的 .name。
final ClaudeJsonSchema kStoryboardSchema = ClaudeJsonSchema(_object(<String, Object?>{
  StoryboardSchemaKeys.contentLanguage: _kString,
  StoryboardSchemaKeys.setting: _object(<String, Object?>{
    DirectorSettingKeys.era: _kString,
    DirectorSettingKeys.region: _kString,
    DirectorSettingKeys.culture: _kString,
    DirectorSettingKeys.artStyle: _kString,
  }),
  StoryboardSchemaKeys.shots: <String, Object?>{
    'type': 'array',
    'items': _object(<String, Object?>{
      StoryboardKeys.label: _kString,
      StoryboardKeys.notes: _kString,
      StoryboardKeys.shotSize: _nullableEnum(ShotSize.values),
      StoryboardKeys.cameraAngle: _nullableEnum(CameraAngle.values),
      StoryboardKeys.camera: _nullableEnum(CameraMovement.values),
      StoryboardKeys.durationSeconds: const <String, Object?>{'type': 'integer'},
      StoryboardKeys.characters: const <String, Object?>{
        'type': 'array',
        'items': _kString,
      },
    }),
  },
}));
