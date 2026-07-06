// OpenAICompatibleImageProvider — 自定义 OpenAI 兼容端点，同步文生图。
//
// 接入参数（PROVIDER-API §13.3，openai-image 协议模板）：
//   Base URL : 用户配置 custom_providers.json 的 base_url
//   Model ID : 用户配置的 model_id（透传请求体 `model`）
//   Auth     : Authorization: Bearer <key>（keySource 读 provider.custom:<id>.api_key）
//   Submit   : POST /images/generations（显式 response_format=b64_json——
//              基类禁止 Provider 内下载远端 URL，必须走 inlineBytes 通道）
//   Validate : GET /models（零生成配额）
//   Poll     : 无（同步返回，走 SyncProviderBase 的 inlineBytes 通道）
//
// capabilities 由协议模板派生（能力位 const，仅 providerId/displayName 实例化）。
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/errors/ink_error.dart';
import '../core/models/custom_provider_config.dart';
import '../core/models/generation_task.dart';
import '../core/models/provider_capabilities.dart';
import '../core/models/provider_protocol_template.dart';
import 'sync_provider_base.dart';

// ---- 接入参数（协议级常量，端点差异只在 baseUrl / model） --------------------
const String kOpenAICompatibleImagePath = '/images/generations';
const String kOpenAICompatibleValidatePath = '/models';

class OpenAICompatibleImageProvider extends SyncProviderBase {
  OpenAICompatibleImageProvider({
    required CustomProviderConfig config,
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  })  : _config = config,
        _capabilities = deriveCustomProviderCapabilities(config);

  final CustomProviderConfig _config;
  final ProviderCapabilities _capabilities;

  @override
  ProviderCapabilities get capabilities => _capabilities;

  @override
  String get baseUrl => _config.baseUrl;

  @override
  String get localJobPrefix => 'local://${_config.providerId}/';

  @override
  Future<Uint8List> performGeneration(
    GenerationTask task,
    String apiKey,
  ) async {
    final body = <String, Object?>{
      'model': _config.modelId,
      'prompt': task.prompt,
      'n': 1,
      'size': _sizeFor(task.aspectRatio),
      // OpenAI 兼容端点默认可能返回 URL——强制 b64_json 走 inlineBytes 通道。
      'response_format': 'b64_json',
    };
    final resp = await dio.post<dynamic>(
      kOpenAICompatibleImagePath,
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
      kOpenAICompatibleValidatePath,
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
    );
  }

  /// 解析 data[0].b64_json。第三方端点响应形态不可信，逐层判定 + base64 容错。
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
    final raw = first is Map ? first['b64_json'] : null;
    final base64Str = raw is String ? raw : null;
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
      // 损坏的 base64 是确定性失败——providerInvalidResponse 不可重试，
      // 与 gemini/openai-image 同款守卫对齐，避免轮询风暴。
      throw ProviderError(
        code: InkErrorCode.providerInvalidResponse,
        extra: {
          'provider_id': capabilities.providerId,
          'reason': 'malformed_b64_json',
        },
      );
    }
  }

  /// AspectRatio → OpenAI 兼容 size 字符串（与 gpt-image-1 同款交集）。
  /// 模板 capabilities 已收窄到三种比例，其余分支为防御性兜底。
  String _sizeFor(AspectRatio ratio) {
    switch (ratio) {
      case AspectRatio.r1x1:
        return '1024x1024';
      case AspectRatio.r16x9:
        return '1536x1024';
      case AspectRatio.r9x16:
        return '1024x1536';
      case AspectRatio.r4x3:
      case AspectRatio.r3x4:
      case AspectRatio.r21x9:
        return '1024x1024';
    }
  }
}
