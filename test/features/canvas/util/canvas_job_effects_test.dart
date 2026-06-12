import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/canvas/util/canvas_job_effects.dart';

JobState _run(String id, String cv, double p) =>
    JobState.running(jobId: id, providerId: 'p', canvasId: cv, progress: p);
JobState _ok(String id, String cv) =>
    JobState.succeeded(jobId: id, providerId: 'p', canvasId: cv, artifactPath: 'a');
JobState _fail(String id, String cv, InkError e) =>
    JobState.failed(jobId: id, providerId: 'p', canvasId: cv, error: e);

void main() {
  const err = NetworkError(code: InkErrorCode.networkOffline, extra: {});

  test('当前画布新增 job → 需重拉，无失败 toast', () {
    final r = CanvasJobEffects.diff(prev: const [], next: [_run('a', 'c1', 0.1)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isTrue);
    expect(r.toastErrors, isEmpty);
  });
  test('别的画布变化 → 不重拉', () {
    final r = CanvasJobEffects.diff(prev: const [], next: [_run('a', 'c2', 0.1)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isFalse);
  });
  test('当前画布 job 转 succeeded → 重拉', () {
    final r = CanvasJobEffects.diff(prev: [_run('a', 'c1', 0.9)], next: [_ok('a', 'c1')], canvasId: 'c1');
    expect(r.shouldReloadNodes, isTrue);
  });
  test('当前画布 job 转 failed → 重拉 + toast 该错误', () {
    final r = CanvasJobEffects.diff(prev: [_run('a', 'c1', 0.9)], next: [_fail('a', 'c1', err)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isTrue);
    expect(r.toastErrors, hasLength(1));
  });
  test('当前画布 job 转 cancelled → 重拉但不 toast', () {
    const cancelled = JobState.cancelled(jobId: 'a', providerId: 'p', canvasId: 'c1');
    final r = CanvasJobEffects.diff(prev: [_run('a', 'c1', 0.9)], next: [cancelled], canvasId: 'c1');
    expect(r.shouldReloadNodes, isTrue);
    expect(r.toastErrors, isEmpty);
  });
  test('当前画布无变化 → 不重拉', () {
    final r = CanvasJobEffects.diff(prev: [_run('a', 'c1', 0.5)], next: [_run('a', 'c1', 0.5)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isFalse);
  });
  // HI-14：进度 tick / 中间态流转 / 终态 job 被清理都不该 invalidate 节点，
  // 否则内存中的拖拽位置每个 tick 回弹一次。
  test('running 进度变化 → 不重拉', () {
    final r = CanvasJobEffects.diff(prev: [_run('a', 'c1', 0.3)], next: [_run('a', 'c1', 0.6)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isFalse);
  });
  test('queued → running 中间态流转 → 不重拉', () {
    const queued = JobState.queued(jobId: 'a', providerId: 'p', canvasId: 'c1');
    final r = CanvasJobEffects.diff(prev: const [queued], next: [_run('a', 'c1', 0.0)], canvasId: 'c1');
    expect(r.shouldReloadNodes, isFalse);
  });
  test('终态 job 被注册表清理 → 不重拉', () {
    final r = CanvasJobEffects.diff(prev: [_ok('a', 'c1')], next: const [], canvasId: 'c1');
    expect(r.shouldReloadNodes, isFalse);
  });
}
