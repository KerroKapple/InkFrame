// StoryboardStep：组请求（分段 system + 剧本 + 驳回意见、结构化输出、effort medium）、
// 解析（正常 / 未知枚举 / 时长越界 / 空标题 / 角色附注 / 坏 JSON / 空表）、落画布草稿。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/claude_message.dart';
import 'package:inkframe/core/models/director.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/models/shot_language.dart';
import 'package:inkframe/features/director/log/director_log.dart';
import 'package:inkframe/features/director/log/director_payloads.dart';
import 'package:inkframe/features/director/pipeline/director_step.dart';
import 'package:inkframe/features/director/steps/storyboard/storyboard_proposal.dart';
import 'package:inkframe/features/director/steps/storyboard/storyboard_step.dart';
import 'package:inkframe/features/storyboard/models/shot_draft.dart';
import 'package:inkframe/features/storyboard/util/script_splitter.dart';

ClaudeMessage _msg(Object json) => ClaudeMessage(
      id: 'm',
      model: 'claude-opus-5-5',
      textBlocks: <String>[json is String ? json : jsonEncode(json)],
      usage: const ClaudeUsage(),
      stopReason: ClaudeStopReason.endTurn,
    );

Map<String, Object?> _shot({
  String label = '山径',
  String notes = '晨雾中杜甫拄杖上山',
  Object? shotSize = 'longShot',
  Object? cameraAngle = 'eyeLevel',
  Object? camera = 'pushIn',
  Object? duration = 5,
  List<Object?> characters = const <Object?>['杜甫'],
}) =>
    <String, Object?>{
      'label': label,
      'notes': notes,
      'shot_size': shotSize,
      'camera_angle': cameraAngle,
      'camera': camera,
      'duration_seconds': duration,
      'characters': characters,
    };

Map<String, Object?> _board(List<Map<String, Object?>> shots) => <String, Object?>{
      'content_language': 'zh-CN',
      'setting': <String, Object?>{
        'era': '唐',
        'region': '蜀中',
        'culture': '',
        'art_style': '水墨',
      },
      'shots': shots,
    };

DirectorSession _session({String lang = '', DirectorSetting setting = DirectorSetting.empty}) =>
    DirectorSession(
      id: 's',
      projectId: 'p',
      canvasId: 'c',
      contentLanguage: lang,
      setting: setting,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

DirectorLog _logWith(String text, {List<String> feedback = const <String>[]}) =>
    DirectorLog(<DirectorEvent>[
      DirectorEvent(
        id: 'e1',
        sessionId: 's',
        seq: 1,
        kind: DirectorEventKind.scriptSubmitted,
        parentSeq: null,
        payload: scriptSubmittedPayload(step: 'storyboard', text: text, feedback: feedback),
        createdAt: DateTime.utc(2026),
      ),
    ]);

class _Writer implements ShotChainWriter {
  List<ShotDraft>? written;
  @override
  Future<List<String>> writeShotChain(List<ShotDraft> drafts) async {
    written = drafts;
    return <String>[for (int i = 0; i < drafts.length; i++) 'n$i'];
  }
}

void main() {
  const StoryboardStep step = StoryboardStep();

  group('buildRequest', () {
    test('分段 system + 剧本包进 <script>；结构化输出、effort medium、末轮是 user', () {
      final ClaudeRequest r = step.buildRequest(
        session: _session(lang: 'zh-CN'),
        log: _logWith('山径破晓'),
        inputSeq: 1,
      );
      expect(r.system, startsWith('<role>'));
      expect(r.system, contains('<hard_rules>'));
      expect(r.system, contains('Write every user-facing field in zh-CN.'));
      expect(r.system, contains('<task>'));
      expect(r.effort, ClaudeEffort.medium);
      expect(r.outputSchema, same(kStoryboardSchema));
      expect(r.messages, hasLength(1));
      expect(r.messages.single.role, ClaudeRole.user);
      expect(r.messages.single.content,
          <ClaudeContentBlock>[const ClaudeTextBlock('<script>\n山径破晓\n</script>')]);
    });

    test('有驳回意见 ⇒ 作为第二段 user 文本注入，按先后', () {
      final ClaudeRequest r = step.buildRequest(
        session: _session(),
        log: _logWith('山径破晓', feedback: <String>['镜头太多', '要有远景']),
        inputSeq: 1,
      );
      final ClaudeTextBlock fb = r.messages.single.content[1] as ClaudeTextBlock;
      expect(fb.text, contains('rejected'));
      expect(fb.text, endsWith('- 镜头太多\n- 要有远景'));
    });

    test('会话已有设定 ⇒ system 里出现设定段', () {
      final ClaudeRequest r = step.buildRequest(
        session: _session(lang: 'zh-CN', setting: const DirectorSetting(era: '唐')),
        log: _logWith('x'),
        inputSeq: 1,
      );
      expect(r.system, contains('<setting>'));
      expect(r.system, contains('Era: 唐'));
    });

    test('输入事件不是 script_submitted ⇒ invalidParameter', () {
      expect(
        () => step.buildRequest(session: _session(), log: DirectorLog(const <DirectorEvent>[]), inputSeq: 1),
        throwsA(isA<ProviderError>()),
      );
    });

    test('schema：每个对象都 additionalProperties:false 且字段全 required；枚举是 .name', () {
      void check(Object? node) {
        if (node is Map) {
          if (node['type'] == 'object') {
            expect(node['additionalProperties'], isFalse);
            expect((node['required'] as List).toSet(),
                (node['properties'] as Map).keys.toSet());
          }
          node.values.forEach(check);
        } else if (node is List) {
          node.forEach(check);
        }
      }

      check(kStoryboardSchema.schema);
      final String json = jsonEncode(kStoryboardSchema.schema);
      expect(json, contains('"extremeCloseUp"'));
      expect(json, contains('"birdsEye"'));
      expect(json, contains('"static_"'));
    });
  });

  group('parse', () {
    test('正常：语言 / 设定 / 每镜字段；角色名附在备注末行', () {
      final StoryboardProposal p = step.parse(_msg(_board(<Map<String, Object?>>[_shot()])));
      expect(p.contentLanguage, 'zh-CN');
      expect(p.setting, const DirectorSetting(era: '唐', region: '蜀中', artStyle: '水墨'));
      final StoryboardShot s = p.shots.single;
      expect(s.label, '山径');
      expect(s.notes, '晨雾中杜甫拄杖上山\n杜甫');
      expect(s.shotSize, ShotSize.longShot);
      expect(s.cameraAngle, CameraAngle.eyeLevel);
      expect(s.camera, CameraMovement.pushIn);
      expect(s.durationMs, 5000);
      expect(s.characters, <String>['杜甫']);
    });

    test('未知枚举 / null ⇒ null', () {
      final StoryboardShot s = step
          .parse(_msg(_board(<Map<String, Object?>>[
            _shot(shotSize: 'cowboyShot', cameraAngle: null, camera: 42),
          ])))
          .shots
          .single;
      expect(s.shotSize, isNull);
      expect(s.cameraAngle, isNull);
      expect(s.camera, isNull);
    });

    test('时长夹到 1–15 秒；缺失取 3 秒；小数四舍五入', () {
      final List<StoryboardShot> shots = step
          .parse(_msg(_board(<Map<String, Object?>>[
            _shot(duration: 0),
            _shot(duration: 99),
            _shot(duration: null),
            _shot(duration: 4.6),
          ])))
          .shots;
      expect(shots.map((StoryboardShot s) => s.durationMs), <int>[1000, 15000, 3000, 5000]);
    });

    test('空标题取备注首行（截到上限）；标题与备注都空的镜丢掉', () {
      final String long = 'x' * (kShotLabelMaxLength + 10);
      final List<StoryboardShot> shots = step
          .parse(_msg(_board(<Map<String, Object?>>[
            _shot(label: '  ', notes: '第一行\n第二行'),
            _shot(label: '', notes: long, characters: const <Object?>[]),
            _shot(label: '', notes: '', characters: const <Object?>[]),
          ])))
          .shots;
      expect(shots, hasLength(2));
      expect(shots[0].label, '第一行');
      expect(shots[1].label, hasLength(kShotLabelMaxLength));
    });

    test('角色名去空去重，按出现顺序', () {
      final StoryboardShot s = step
          .parse(_msg(_board(<Map<String, Object?>>[
            _shot(characters: const <Object?>['杜甫', ' ', '李白', '杜甫', 7]),
          ])))
          .shots
          .single;
      expect(s.characters, <String>['杜甫', '李白']);
      expect(s.notes.split('\n').last, '杜甫 · 李白');
    });

    test('不是 JSON / 不是对象 / 没有镜 ⇒ providerInvalidResponse', () {
      Matcher invalid(String reason) => throwsA(isA<ProviderError>()
          .having((ProviderError e) => e.code, 'code', InkErrorCode.providerInvalidResponse)
          .having((ProviderError e) => e.extra['reason'], 'reason', reason));
      expect(() => step.parse(_msg('not json')), invalid('storyboard_not_json'));
      expect(() => step.parse(_msg('[1]')), invalid('storyboard_not_object'));
      expect(() => step.parse(_msg(_board(const <Map<String, Object?>>[]))),
          invalid('storyboard_empty'));
    });
  });

  test('提案 JSON 往返（日志重建）', () {
    final StoryboardProposal p = step.parse(_msg(_board(<Map<String, Object?>>[_shot(), _shot(camera: null)])));
    final StoryboardProposal back =
        step.decodeProposal((jsonDecode(jsonEncode(step.encodeProposal(p))) as Map).cast<String, Object?>());
    expect(back.toJson(), p.toJson());
  });

  test('sessionPatchOf：空语言 / 空设定不写回', () {
    final StoryboardProposal p = StoryboardProposal(
      contentLanguage: '',
      setting: DirectorSetting.empty,
      shots: <StoryboardShot>[],
    );
    expect(step.sessionPatchOf(p), (contentLanguage: null, setting: null));
  });

  test('apply：每镜一份带镜头语言的草稿，交给同一条建链路径', () async {
    final StoryboardProposal p = step.parse(_msg(_board(<Map<String, Object?>>[_shot()])));
    final _Writer w = _Writer();
    expect(await step.apply(p, w), <String>['n0']);
    expect(w.written, <ShotDraft>[
      const ShotDraft(
        label: '山径',
        notes: '晨雾中杜甫拄杖上山\n杜甫',
        shotSize: ShotSize.longShot,
        cameraAngle: CameraAngle.eyeLevel,
        camera: CameraMovement.pushIn,
        durationMs: 5000,
      ),
    ]);
  });
}
