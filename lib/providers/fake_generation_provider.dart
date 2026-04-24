// FakeGenerationProvider：本地开发用假 Provider，不调真 API。
//
// 用法：INKFRAME_FAKE_PROVIDERS=1 时 providers.dart 用它替换所有真 Provider，
// 方便走完整 UI 流程（FAB → Inspector → Generate → 轮询 → 缩略 → 灯箱）
// 不消耗 DashScope 配额。
//
// 行为：
//   submit  → 300ms 后返回 "fake-<ts>" jobId
//   poll    → 前 2 次 inProgress(0.33/0.67)，第 3 次 success(公开 sample URL)
//   cancel  → no-op
//   validate → 始终 valid
//
// 返回 URL 是公开可访问的小样本（Big Buck Bunny 1MB / picsum 512）。
// 注意：需要可访问外网才能下载到本地缩略/视频。
import 'dart:async';

import '../core/interfaces/generation_provider.dart';
import '../core/models/generation_task.dart';
import '../core/models/job_status.dart';
import '../core/models/key_validation_result.dart';
import '../core/models/provider_capabilities.dart';

class FakeGenerationProvider
    implements Submittable, Pollable, Cancellable, KeyValidatable {
  FakeGenerationProvider(this.capabilities);

  @override
  final ProviderCapabilities capabilities;

  static const String _sampleVideoUrl =
      'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4';
  static const String _sampleImageUrl = 'https://picsum.photos/seed/inkframe/512';

  final Map<JobId, _FakeJobState> _jobs = <JobId, _FakeJobState>{};

  @override
  Future<JobId> submit(GenerationTask task) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final id = 'fake-${DateTime.now().microsecondsSinceEpoch}';
    _jobs[id] = _FakeJobState(mode: task.mode, pollCount: 0);
    return id;
  }

  @override
  Future<JobStatus> poll(JobId id) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final state = _jobs[id];
    if (state == null) {
      return const JobStatus.inProgress();
    }
    state.pollCount += 1;
    if (state.pollCount < 3) {
      return JobStatus.inProgress(progress: state.pollCount / 3.0);
    }
    final isVideo = state.mode == GenerationMode.textToVideo ||
        state.mode == GenerationMode.imageToVideo;
    return JobStatus.success(
      remoteUrls: <String>[isVideo ? _sampleVideoUrl : _sampleImageUrl],
    );
  }

  @override
  Future<void> cancel(JobId id) async {
    _jobs.remove(id);
  }

  @override
  Future<KeyValidationResult> validateApiKey(String key) async {
    return const KeyValidationResult.valid(accountInfo: 'fake-provider');
  }
}

class _FakeJobState {
  _FakeJobState({required this.mode, required this.pollCount});
  final GenerationMode mode;
  int pollCount;
}
