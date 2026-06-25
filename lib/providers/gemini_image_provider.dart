// GeminiImageProvider — Gemini 2.5 flash image preview 同步生成。
//
// PRD §10.2.1 接入参数：
//   Base URL : https://generativelanguage.googleapis.com/v1beta
//   Model ID : gemini-2.5-flash-image-preview
//   Auth     : x-goog-api-key 请求头（从 keySource 读取；LO-13 禁止进 URL）
//   Submit   : POST /models/{model}:generateContent
//   Poll     : 无（同步返回，走 SyncProviderBase 的 inlineBytes 通道）
//
// 共享脚手架见 SyncProviderBase；本文件仅声明能力 + Gemini 专有的请求体/解析/审核判定。
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/errors/ink_error.dart';
import '../core/models/cost_model.dart';
import '../core/models/generation_task.dart';
import '../core/models/provider_capabilities.dart';
import 'sync_provider_base.dart';

// ---- 接入参数（PRD §10.2.1 锁定） ----------------------------------------
const String kGeminiBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta';
const String kGeminiModel = 'gemini-2.5-flash-image-preview';
const String kGeminiSubmitPath = '/models/$kGeminiModel:generateContent';
const String kGeminiValidatePath = '/models';

/// LO-13：API Key 经请求头传递，绝不进 URL query（防日志/代理泄露）。
const String kGeminiApiKeyHeader = 'x-goog-api-key';

/// 同步返回的 inline 图片数据在本地生成 JobId 时使用的前缀。
const String kGeminiLocalJobPrefix = 'local://gemini-image/';

// ---- 能力声明（PROVIDER-API.md §9.2） -----------------------------------
const ProviderCapabilities kGeminiImageCapabilities = ProviderCapabilities(
  providerId: 'gemini-image',
  displayName: 'Gemini Image',
  region: ProviderRegion.global,
  modes: [GenerationMode.textToImage],
  supportedRatios: [
    AspectRatio.r1x1,
    AspectRatio.r16x9,
    AspectRatio.r9x16,
    AspectRatio.r4x3,
    AspectRatio.r3x4,
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
  supportsSeed: true,
  supportsSound: false,
  supportsBatch: false,
  supportsCancellation: false,
  // 同步 Provider 仍走 Pollable 路径（poll 一调即返回 inlineBytes，详见 ADR-0004）。
  supportsPolling: true,
  costModel: CostModel.perCharInput(
    usdPerKChar: 0.000075,
    usdPerImageOutput: 0.039,
  ),
  maxConcurrentJobs: 1,
  qps: 2,
  burst: 10,
);

class GeminiImageProvider extends SyncProviderBase {
  GeminiImageProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  ProviderCapabilities get capabilities => kGeminiImageCapabilities;

  @override
  String get baseUrl => kGeminiBaseUrl;

  @override
  String get localJobPrefix => kGeminiLocalJobPrefix;

  @override
  Future<Uint8List> performGeneration(
    GenerationTask task,
    String apiKey,
  ) async {
    final body = <String, Object?>{
      'contents': [
        {
          'parts': [
            {'text': task.prompt},
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        if (task.seed != null) 'seed': task.seed,
        // HI-27：image-preview 模型要求 TEXT+IMAGE 双模态，仅 IMAGE 会被拒。
        'responseModalities': ['TEXT', 'IMAGE'],
        // HI-07：aspectRatio 接入 imageConfig，不许静默忽略。
        'imageConfig': <String, Object?>{
          'aspectRatio': _aspectRatioFor(task.aspectRatio),
        },
      },
    };
    final resp = await dio.post<dynamic>(
      kGeminiSubmitPath,
      data: body,
      options: Options(
        contentType: 'application/json',
        headers: {kGeminiApiKeyHeader: apiKey},
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
      kGeminiValidatePath,
      queryParameters: {'pageSize': 1},
      options: Options(headers: {kGeminiApiKeyHeader: apiKey}),
    );
  }

  @override
  InkError? contentPolicyFromDioError(DioException e) {
    // Gemini 400 的 message 包含 "SAFETY" / "blocked" → 归 content_policy。
    if (e.response?.statusCode == 400 && _isContentPolicy(e.response?.data)) {
      return ProviderError(
        code: InkErrorCode.contentPolicy,
        extra: {'provider_id': capabilities.providerId},
        cause: e,
      );
    }
    return null;
  }

  /// 解析 candidates[].content.parts[].inlineData.data（base64）为原始字节。
  Uint8List _decodeInlineImage(Map<String, Object?>? data) {
    if (data == null) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'empty_body'},
      );
    }
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'no_candidates',
        },
      );
    }
    // 远端 schema 漂移防御（评审 P1#4）：候选/内容形态异常 → providerInvalidResponse，
    // 不让裸 `as Map` 炸成 _TypeError → UnknownError。
    final first = candidates.first;
    if (first is! Map) {
      throw ProviderError(
        code: InkErrorCode.providerInvalidResponse,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'malformed_candidate',
        },
      );
    }
    final content = first['content'];
    if (content is! Map) {
      throw ProviderError(
        code: InkErrorCode.providerInvalidResponse,
        extra: {'provider_id': capabilities.providerId, 'reason': 'no_content'},
      );
    }
    final parts = content['parts'];
    if (parts is! List) {
      throw ProviderError(
        code: InkErrorCode.providerServer,
        extra: {'provider_id': capabilities.providerId, 'reason': 'no_parts'},
      );
    }
    for (final p in parts) {
      if (p is Map && p['inlineData'] is Map) {
        final base64Str = (p['inlineData'] as Map)['data'] as String?;
        if (base64Str != null) {
          return base64Decode(base64Str);
        }
      }
    }
    throw ProviderError(
      code: InkErrorCode.providerServer,
      extra: {
        'provider_id': capabilities.providerId,
        'reason': 'no_inline_data',
      },
    );
  }

  /// AspectRatio 枚举 → Gemini imageConfig.aspectRatio 字面量。
  /// capabilities 已收窄到前五种；r21x9 为防御性兜底。
  String _aspectRatioFor(AspectRatio ratio) {
    switch (ratio) {
      case AspectRatio.r1x1:
        return '1:1';
      case AspectRatio.r16x9:
        return '16:9';
      case AspectRatio.r9x16:
        return '9:16';
      case AspectRatio.r4x3:
        return '4:3';
      case AspectRatio.r3x4:
        return '3:4';
      case AspectRatio.r21x9:
        return '21:9';
    }
  }

  bool _isContentPolicy(Object? body) {
    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        final msg = (err['message'] as String?)?.toLowerCase() ?? '';
        return msg.contains('safety') || msg.contains('blocked');
      }
    }
    return false;
  }
}
