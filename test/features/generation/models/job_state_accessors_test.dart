// JobStateX 访问器全变体覆盖：jobId / providerId / canvasId 三个 switch 在
// 六个变体上各取一次（含 JobFailed），并补 JobCancelled 的 progressValue。
//
// 补 job_state_test.dart：原测只在部分变体上读访问器，failed 臂与
// cancelled 的 progressValue 哨兵未被触达。
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

  group('JobStateX 访问器对每个变体都返回各自的值', () {
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

  group('progressValue 哨兵', () {
    test('JobSubmitting / JobCancelled → 0.0', () {
      const sub = JobState.submitting(jobId: 'j', providerId: 'p', canvasId: 'c');
      const can = JobState.cancelled(jobId: 'j', providerId: 'p', canvasId: 'c');
      expect(sub.progressValue, 0.0);
      expect(can.progressValue, 0.0);
    });
  });
}
