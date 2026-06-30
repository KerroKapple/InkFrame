// JobState sealed union + extension 行为单测。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/generation/models/job_state.dart';

void main() {
  group('JobState sealed', () {
    test('六种构造各自可区分', () {
      const q = JobState.queued(jobId: 'j1', providerId: 'p', canvasId: 'cv');
      const s = JobState.submitting(jobId: 'j1', providerId: 'p', canvasId: 'cv');
      const r = JobState.running(jobId: 'j1', providerId: 'p', canvasId: 'cv', progress: 0.4);
      const ok = JobState.succeeded(
        jobId: 'j1',
        providerId: 'p',
        canvasId: 'cv',
        artifactPath: 'images/j1-0.png',
      );
      const failed = JobState.failed(
        jobId: 'j1',
        providerId: 'p',
        canvasId: 'cv',
        error: NetworkError(code: InkErrorCode.networkTimeout),
      );
      const cancelled = JobState.cancelled(jobId: 'j1', providerId: 'p', canvasId: 'cv');
      expect(q, isA<JobQueued>());
      expect(s, isA<JobSubmitting>());
      expect(r, isA<JobRunning>());
      expect(ok, isA<JobSucceeded>());
      expect(failed, isA<JobFailed>());
      expect(cancelled, isA<JobCancelled>());
    });

    test('exhaustive switch 覆盖六种', () {
      const r = JobState.running(jobId: 'j1', providerId: 'p', canvasId: 'cv', progress: 0.2);
      final label = switch (r) {
        JobQueued() => 'queued',
        JobSubmitting() => 'submitting',
        JobRunning() => 'running',
        JobSucceeded() => 'succeeded',
        JobFailed() => 'failed',
        JobCancelled() => 'cancelled',
      };
      expect(label, 'running');
    });

    test('每个 JobState 变体都带 canvasId 且可读', () {
      const c = 'cv-1';
      final states = <JobState>[
        const JobState.queued(jobId: 'j', providerId: 'p', canvasId: c),
        const JobState.submitting(jobId: 'j', providerId: 'p', canvasId: c),
        const JobState.running(jobId: 'j', providerId: 'p', canvasId: c, progress: 0.5),
        const JobState.succeeded(jobId: 'j', providerId: 'p', canvasId: c, artifactPath: 'a.png'),
        const JobState.cancelled(jobId: 'j', providerId: 'p', canvasId: c),
      ];
      for (final s in states) {
        expect(s.canvasId, c);
      }
    });
  });

  group('JobStateX', () {
    test('jobId / providerId 通过 extension 暴露', () {
      const r = JobState.running(jobId: 'abc', providerId: 'gemini-image', canvasId: 'cv');
      expect(r.jobId, 'abc');
      expect(r.providerId, 'gemini-image');
    });

    test('isTerminal / isActive 区分终态与活跃态', () {
      const q = JobState.queued(jobId: 'j', providerId: 'p', canvasId: 'cv');
      const s = JobState.submitting(jobId: 'j', providerId: 'p', canvasId: 'cv');
      const r = JobState.running(jobId: 'j', providerId: 'p', canvasId: 'cv');
      const ok = JobState.succeeded(
        jobId: 'j',
        providerId: 'p',
        canvasId: 'cv',
        artifactPath: 'a',
      );
      const failed = JobState.failed(
        jobId: 'j',
        providerId: 'p',
        canvasId: 'cv',
        error: UnknownError(cause: 'x'),
      );
      const cancelled = JobState.cancelled(jobId: 'j', providerId: 'p', canvasId: 'cv');
      expect([q, s, r].every((e) => e.isActive && !e.isTerminal), isTrue);
      expect(
        [ok, failed, cancelled].every((e) => e.isTerminal && !e.isActive),
        isTrue,
      );
    });

    test('isCancellable 仅活跃态为 true', () {
      const r = JobState.running(jobId: 'j', providerId: 'p', canvasId: 'cv');
      const ok = JobState.succeeded(
        jobId: 'j',
        providerId: 'p',
        canvasId: 'cv',
        artifactPath: 'a',
      );
      expect(r.isCancellable, isTrue);
      expect(ok.isCancellable, isFalse);
    });

    test('isRetryable：仅 failed 且 InkError.retryable=true', () {
      const retryable = JobState.failed(
        jobId: 'j',
        providerId: 'p',
        canvasId: 'cv',
        error: NetworkError(code: InkErrorCode.networkTimeout),
      );
      const notRetryable = JobState.failed(
        jobId: 'j',
        providerId: 'p',
        canvasId: 'cv',
        error: ProviderError(code: InkErrorCode.invalidKey),
      );
      const cancelled = JobState.cancelled(jobId: 'j', providerId: 'p', canvasId: 'cv');
      expect(retryable.isRetryable, isTrue);
      expect(notRetryable.isRetryable, isFalse);
      expect(cancelled.isRetryable, isFalse);
    });

    test('progressValue：running 取 progress，终态分别哨兵', () {
      const r = JobState.running(jobId: 'j', providerId: 'p', canvasId: 'cv', progress: 0.42);
      const ok = JobState.succeeded(
        jobId: 'j',
        providerId: 'p',
        canvasId: 'cv',
        artifactPath: 'a',
      );
      const failed = JobState.failed(
        jobId: 'j',
        providerId: 'p',
        canvasId: 'cv',
        error: UnknownError(cause: 'x'),
      );
      const q = JobState.queued(jobId: 'j', providerId: 'p', canvasId: 'cv');
      expect(r.progressValue, closeTo(0.42, 1e-9));
      expect(ok.progressValue, 1.0);
      expect(failed.progressValue, 0.0);
      expect(q.progressValue, 0.0);
    });

    test('progressValue 钳制在 [0,1]', () {
      const a = JobState.running(jobId: 'j', providerId: 'p', canvasId: 'cv', progress: 1.5);
      const b = JobState.running(jobId: 'j', providerId: 'p', canvasId: 'cv', progress: -0.3);
      expect(a.progressValue, 1.0);
      expect(b.progressValue, 0.0);
    });

    test('sourceNodeId：可选字段，默认 null，各变体可读', () {
      const withNode = JobState.running(
        jobId: 'j',
        providerId: 'p',
        canvasId: 'cv',
        sourceNodeId: 'cfg-7',
      );
      const withoutNode =
          JobState.queued(jobId: 'j', providerId: 'p', canvasId: 'cv');
      expect(withNode.sourceNodeId, 'cfg-7');
      expect(withoutNode.sourceNodeId, isNull);
    });
  });
}
