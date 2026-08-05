// OpenAIImageProvider — OpenAI gpt-image-2 同步文生图。
//
// 接入参数（MOD-1 升级 2026-08-05；gpt-image-1 于 2026-10-23 弃用，
// gpt-image-1.5 亦于 2026-12-01 退役故不作过渡，直升 gpt-image-2）：
//   Base URL : https://api.openai.com/v1
//   Model ID : gpt-image-2（同步，固定返回 b64_json，不接受 response_format——
//              GPT image 系列共性,契约与 gpt-image-1 兼容）
//   Size     : 任意 WIDTHxHEIGHT（两边 16 整除,长短边比 ≤3:1,总像素
//              655,360~8,294,400,最长边 ≤3840）——本档取三比例的真尺寸
//   Auth     : Authorization: Bearer <key>（从 keySource 读取）
//   Submit   : POST /images/generations
//   Validate : GET /models（零生成配额）
//   Poll     : 无（同步返回，走 SyncProviderBase 的 inlineBytes 通道）
//
// 共享脚手架见 SyncProviderBase；本文件仅声明能力 + OpenAI 专有的请求体/解析/审核判定。
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/errors/ink_error.dart';
import '../core/models/cost_model.dart';
import '../core/models/generation_task.dart';
import '../core/models/provider_capabilities.dart';
import 'sync_provider_base.dart';

// ---- 接入参数（计划锁定） -------------------------------------------------
const String kOpenAIBaseUrl = 'https://api.openai.com/v1';
const String kOpenAIModel = 'gpt-image-2';
const String kOpenAIImagePath = '/images/generations';
const String kOpenAIValidatePath = '/models';

/// 同步返回的 inline 图片数据在本地合成 JobId 时使用的前缀。
const String kOpenAILocalJobPrefix = 'local://openai-image/';

// ---- 能力声明（PROVIDER-API.md §9.2） -----------------------------------
const ProviderCapabilities kOpenAIImageCapabilities = ProviderCapabilities(
  providerId: 'openai-image',
  displayName: 'OpenAI Image',
  region: ProviderRegion.global,
  modes: [GenerationMode.textToImage],
  // gpt-image-2 支持任意尺寸;本档三比例走真尺寸（16:9 分镜第一刚需）。
  supportedRatios: [
    AspectRatio.r1x1,
    AspectRatio.r16x9,
    AspectRatio.r9x16,
  ],
  supportedResolutions: [Resolution.p1080],
  supportedDurations: [],
  supportedCameras: [],
  maxBatchSize: 1,
  maxRefImages: 0,
  refImagesIncludeKeyframes: false,
  supportsFirstFrame: false,
  supportsLastFrame: false,
  supportsNegativePrompt: false,
  supportsSeed: false, // gpt-image-2 无 seed 参数
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: false,
  // 同步 Provider 仍走 Pollable 路径（poll 一调即返回 inlineBytes，详见 ADR-0004）。
  supportsPolling: true,
  // gpt-image-2 medium 质量标准分辨率官方档 $0.041–0.053,取 1024² 档。
  costModel: CostModel.perCall(usdPerCall: 0.041),
  maxConcurrentJobs: 1,
  qps: 2,
  burst: 5,
);

class OpenAIImageProvider extends SyncProviderBase {
  OpenAIImageProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  ProviderCapabilities get capabilities => kOpenAIImageCapabilities;

  @override
  String get baseUrl => kOpenAIBaseUrl;

  @override
  String get localJobPrefix => kOpenAILocalJobPrefix;

  @override
  Future<Uint8List> performGeneration(
    GenerationTask task,
    String apiKey,
  ) async {
    final body = <String, Object?>{
      'model': kOpenAIModel,
      'prompt': task.prompt,
      'n': 1,
      'size': _sizeFor(task.aspectRatio),
      'quality': 'medium',
      // HI-06：GPT image 系列不接受 response_format（带上即 400），固定返回 b64_json。
    };
    final resp = await dio.post<dynamic>(
      kOpenAIImagePath,
      data: body,
      options: Options(
        contentType: 'application/json',
        headers: {'Authorization': 'Bearer $apiKey'},
      ),
    );
    final data = resp.data is Map
        ? Map<String, Object?>.from(resp.data as Map)
        : null;
    return _decodeInlineImage(data);
  }

  @override
  Future<void> performKeyValidation(String apiKey) async {
    await dio.get<dynamic>(
      kOpenAIValidatePath,
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
    );
  }

  @override
  InkError? contentPolicyFromDioError(DioException e) {
    // OpenAI 400 不靠 HTTP 状态码区分内容策略——必须先读 error.code。
    if (e.response?.statusCode == 400 &&
        _isContentPolicyViolation(e.response?.data)) {
      return ProviderError(
        code: InkErrorCode.contentPolicy,
        extra: {'provider_id': capabilities.providerId},
        cause: e,
      );
    }
    return null;
  }

  /// 解析 data[0].b64_json（base64）为原始字节。
  Uint8List _decodeInlineImage(Map<String, Object?>? data) {
    if (data == null) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'empty_body'},
      );
    }
    final entries = data['data'];
    if (entries is! List || entries.isEmpty) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'no_data'},
      );
    }
    final first = entries.first;
    final base64Str = first is Map ? first['b64_json'] as String? : null;
    if (base64Str == null) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'no_b64_json',
        },
      );
    }
    try {
      return base64Decode(base64Str);
    } on FormatException {
      // 损坏的 base64 是确定性失败——不可重试，避免轮询风暴。
      throw ProviderError(
        code: InkErrorCode.providerInvalidResponse,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'malformed_b64_json',
        },
      );
    }
  }

  /// AspectRatio → gpt-image-2 size 字符串（真比例；约束=两边 16 整除、
  /// 比 ≤3:1、总像素 655,360~8,294,400）。gpt-image-1 时代 16:9 只能凑
  /// 3:2(1536x1024)，MOD-1 起走真 16:9。capabilities 已收窄到三种比例，
  /// 其余分支为防御性兜底（UI 遵守 supportedRatios 时不可达）。
  String _sizeFor(AspectRatio ratio) {
    switch (ratio) {
      case AspectRatio.r1x1:
        return '1024x1024';
      case AspectRatio.r16x9:
        return '1536x864';
      case AspectRatio.r9x16:
        return '864x1536';
      case AspectRatio.r4x3:
      case AspectRatio.r3x4:
      case AspectRatio.r21x9:
        return '1024x1024';
    }
  }

  bool _isContentPolicyViolation(Object? body) {
    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        return err['code'] == 'content_policy_violation';
      }
    }
    return false;
  }
}
