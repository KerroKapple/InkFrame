// nodeStatusOf：节点卡状态行与左栏大纲行共用的唯一状态判据（PR-4 从 node_card 的 _StatusRow 抽出）。
//
// 抽出前后的口径必须一字不差（节点卡的 golden 只在 CI 跑，这里在本地就把语义钉住）；
// 新增的只有 hasArtifact：大纲行用它把「名下已有产物的配置节点」报成完成，节点卡不传。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/features/generation/models/job_state.dart';

CanvasNode _config(CanvasNodeType type, Map<String, Object?> typeConfig) => CanvasNode(
      id: 'n',
      label: 'n',
      type: type,
      typeConfig: typeConfig,
    );

void main() {
  const CanvasNode prompted = CanvasNode(
    id: 'n',
    label: 'n',
    type: CanvasNodeType.image,
    typeConfig: <String, Object?>{'prompt': 'river at dawn'},
  );

  group('有活动 job', () {
    test('running → 进行中 + 百分比（四舍五入）', () {
      final NodeStatus s = nodeStatusOf(
        prompted,
        job: const JobState.running(
          jobId: 'j',
          providerId: 'p',
          canvasId: 'c',
          progress: 0.616,
        ),
      );
      expect(s, (kind: NodeStatusKind.running, percent: 62));
    });

    test('queued / submitting → 排队中', () {
      for (final JobState job in const <JobState>[
        JobState.queued(jobId: 'j', providerId: 'p', canvasId: 'c'),
        JobState.submitting(jobId: 'j', providerId: 'p', canvasId: 'c'),
      ]) {
        expect(nodeStatusOf(prompted, job: job).kind, NodeStatusKind.queued);
      }
    });

    test('job 压过产物与提示词：有产物也报进行中', () {
      final NodeStatus s = nodeStatusOf(
        prompted,
        job: const JobState.running(jobId: 'j', providerId: 'p', canvasId: 'c'),
        hasArtifact: true,
      );
      expect(s.kind, NodeStatusKind.running);
    });

    test('终态（nodeActiveJobProvider 里到不了）按就绪报——与抽出前的 default 分支同口径', () {
      final NodeStatus s = nodeStatusOf(
        prompted,
        job: const JobState.failed(
          jobId: 'j',
          providerId: 'p',
          canvasId: 'c',
          error: LocalIOError(),
        ),
      );
      expect(s.kind, NodeStatusKind.ready);
    });
  });

  group('没有活动 job · config 节点', () {
    test('有产物（只有大纲会传）→ 完成；节点卡不传 → 仍看提示词', () {
      expect(nodeStatusOf(prompted, job: null, hasArtifact: true).kind, NodeStatusKind.done);
      expect(nodeStatusOf(prompted, job: null).kind, NodeStatusKind.ready);
    });

    test('正文的取法按类型：image / video 看 prompt，text 看 text，shot 看 shot_notes', () {
      expect(nodeStatusOf(_config(CanvasNodeType.video, <String, Object?>{'prompt': 'x'}), job: null).kind,
          NodeStatusKind.ready);
      expect(nodeStatusOf(_config(CanvasNodeType.text, <String, Object?>{'text': 'x'}), job: null).kind,
          NodeStatusKind.ready);
      expect(nodeStatusOf(_config(CanvasNodeType.shot, <String, Object?>{'shot_notes': 'x'}), job: null).kind,
          NodeStatusKind.ready);
      // 写在别的键里不算：text 节点的 prompt、shot 节点的 prompt 都不是它的正文。
      expect(nodeStatusOf(_config(CanvasNodeType.text, <String, Object?>{'prompt': 'x'}), job: null).kind,
          NodeStatusKind.draft);
      expect(nodeStatusOf(_config(CanvasNodeType.shot, <String, Object?>{'prompt': 'x'}), job: null).kind,
          NodeStatusKind.draft);
    });

    test('只有空白 / 没写 → 草稿', () {
      expect(nodeStatusOf(_config(CanvasNodeType.image, <String, Object?>{'prompt': '   '}), job: null).kind,
          NodeStatusKind.draft);
      expect(nodeStatusOf(_config(CanvasNodeType.image, const <String, Object?>{}), job: null).kind,
          NodeStatusKind.draft);
    });
  });

  group('没有活动 job · result 节点', () {
    test('有产物 url → 完成；没有 → 等待中（hasArtifact 对 result 不起作用）', () {
      const CanvasNode done = CanvasNode(
        id: 'r',
        label: 'r',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        typeConfig: <String, Object?>{'image_url': 'images/a.png'},
      );
      const CanvasNode pending = CanvasNode(
        id: 'r',
        label: 'r',
        type: CanvasNodeType.image,
        role: NodeRole.result,
      );
      expect(nodeStatusOf(done, job: null).kind, NodeStatusKind.done);
      expect(nodeStatusOf(pending, job: null).kind, NodeStatusKind.pending);
      expect(nodeStatusOf(pending, job: null, hasArtifact: true).kind, NodeStatusKind.pending);
    });
  });
}
