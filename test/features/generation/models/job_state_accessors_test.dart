// JobState 共享字段契约的全变体覆盖：jobId / providerId / canvasId /
// resultNodeId / projectId 在六个变体上各取一次（含 JobFailed），
// 并补 JobCancelled 的 progressValue 哨兵。
//
// 补 job_state_test.dart：原测只在部分变体上读这些字段，failed 臂与
// cancelled 的 progressValue 哨兵未被触达。
//
// 【本文件测的是生成码，不是扩展】这几个字段六变体同名同类型，freezed 把它们
// 生成到共享 `mixin _$JobState` 上，`s.jobId` 解析到的就是那一份。本文件的价值
// 在于钉死**字段契约**——某个变体漏掉一个字段，它就会从共享 mixin 上掉下来，
// 全部消费点编译失败；而不是在"测一个手写的六臂 switch"（那一份曾真实存在，
// 被共享 mixin 遮蔽成死代码，已删；闸见
// test/quality/no_shadowed_extension_member_test.dart）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/generation/models/job_state.dart';

void main() {
  // 六变体各一，jobId/providerId/canvasId 取唯一值便于断言归属正确。
  final all = <JobState>[
    const JobState.queued(jobId: 'jq', providerId: 'pq', canvasId: 'cq'),
    const JobState.submitting(jobId: 'js', providerId: 'ps', canvasId: 'cs'),
    const JobState.running(
      jobId: 'jr',
      providerId: 'pr',
      canvasId: 'cr',
      progress: 0.3,
    ),
    const JobState.succeeded(
      jobId: 'jok',
      providerId: 'pok',
      canvasId: 'cok',
      artifactPath: 'images/a.png',
    ),
    const JobState.failed(
      jobId: 'jf',
      providerId: 'pf',
      canvasId: 'cf',
      error: NetworkError(code: InkErrorCode.networkTimeout),
    ),
    const JobState.cancelled(jobId: 'jc', providerId: 'pc', canvasId: 'cc'),
  ];

  group('共享字段在每个变体上都返回各自的值', () {
    test('jobId 在六变体上各取本体值（含 failed 臂）', () {
      expect(all.map((s) => s.jobId).toList(),
          ['jq', 'js', 'jr', 'jok', 'jf', 'jc']);
    });

    test('providerId 在六变体上各取本体值', () {
      expect(all.map((s) => s.providerId).toList(),
          ['pq', 'ps', 'pr', 'pok', 'pf', 'pc']);
    });

    test('canvasId 在六变体上各取本体值', () {
      expect(all.map((s) => s.canvasId).toList(),
          ['cq', 'cs', 'cr', 'cok', 'cf', 'cc']);
    });
  });

  group('resultNodeId 共享字段', () {
    test('缺省为 null（六变体）', () {
      expect(all.map((s) => s.resultNodeId).toList(), List.filled(6, null));
    });

    test('六变体上各取本体值', () {
      final withNode = <JobState>[
        const JobState.queued(
            jobId: 'j', providerId: 'p', canvasId: 'c', resultNodeId: 'rq'),
        const JobState.submitting(
            jobId: 'j', providerId: 'p', canvasId: 'c', resultNodeId: 'rs'),
        const JobState.running(
            jobId: 'j', providerId: 'p', canvasId: 'c', resultNodeId: 'rr'),
        const JobState.succeeded(
            jobId: 'j',
            providerId: 'p',
            canvasId: 'c',
            resultNodeId: 'rok',
            artifactPath: 'a'),
        const JobState.failed(
            jobId: 'j',
            providerId: 'p',
            canvasId: 'c',
            resultNodeId: 'rf',
            error: NetworkError(code: InkErrorCode.networkTimeout)),
        const JobState.cancelled(
            jobId: 'j', providerId: 'p', canvasId: 'c', resultNodeId: 'rc'),
      ];
      expect(withNode.map((s) => s.resultNodeId).toList(),
          ['rq', 'rs', 'rr', 'rok', 'rf', 'rc']);
    });
  });

  // projectId 进六个变体是「画廊脏标记按项目分」的前提：registry 是全 app 级
  // 内存镜像，条目上只有 canvasId 时，任何一条成功 job 都只能当全局脏标记用。
  group('projectId 共享字段', () {
    test('缺省为 null（六变体）', () {
      expect(all.map((s) => s.projectId).toList(), List.filled(6, null));
    });

    test('六变体上各取本体值', () {
      final withProject = <JobState>[
        const JobState.queued(
            jobId: 'j', providerId: 'p', canvasId: 'c', projectId: 'pq'),
        const JobState.submitting(
            jobId: 'j', providerId: 'p', canvasId: 'c', projectId: 'ps'),
        const JobState.running(
            jobId: 'j', providerId: 'p', canvasId: 'c', projectId: 'pr'),
        const JobState.succeeded(
            jobId: 'j',
            providerId: 'p',
            canvasId: 'c',
            projectId: 'pok',
            artifactPath: 'a'),
        const JobState.failed(
            jobId: 'j',
            providerId: 'p',
            canvasId: 'c',
            projectId: 'pf',
            error: NetworkError(code: InkErrorCode.networkTimeout)),
        const JobState.cancelled(
            jobId: 'j', providerId: 'p', canvasId: 'c', projectId: 'pc'),
      ];
      expect(withProject.map((s) => s.projectId).toList(),
          ['pq', 'ps', 'pr', 'pok', 'pf', 'pc']);
    });
  });

  group('progressValue 哨兵', () {
    test('JobSubmitting / JobCancelled → 0.0', () {
      const sub = JobState.submitting(jobId: 'j', providerId: 'p', canvasId: 'c');
      const can = JobState.cancelled(jobId: 'j', providerId: 'p', canvasId: 'c');
      expect(sub.progressValue, 0.0);
      expect(can.progressValue, 0.0);
    });
  });
}
