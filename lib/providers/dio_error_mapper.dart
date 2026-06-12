// DioException → InkError 统一映射（PROVIDER-API.md §6.3）。
//
// 所有 Provider 在 HTTP 层之上必须调用本函数，业务代码禁止见到裸 DioException。

import 'package:dio/dio.dart';

import '../core/errors/ink_error.dart';

InkError mapDioError(DioException e, {required String providerId}) {
  final extra = <String, Object?>{'provider_id': providerId};

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return NetworkError(
        code: InkErrorCode.networkTimeout,
        extra: extra,
        cause: e,
      );
    case DioExceptionType.connectionError:
      return NetworkError(
        code: InkErrorCode.networkOffline,
        extra: extra,
        cause: e,
      );
    case DioExceptionType.badCertificate:
      return NetworkError(
        code: InkErrorCode.networkOffline,
        extra: {...extra, 'reason': 'bad_certificate'},
        cause: e,
      );
    case DioExceptionType.cancel:
      return CancelledError.byUser(extra: extra);
    case DioExceptionType.unknown:
      return UnknownError(cause: e, extra: extra, stackTrace: e.stackTrace);
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return ProviderError(
          code: InkErrorCode.invalidKey,
          extra: {...extra, 'status': status},
          cause: e,
        );
      }
      if (status == 402) {
        return ProviderError(
          code: InkErrorCode.insufficientBalance,
          extra: {...extra, 'status': status},
          cause: e,
        );
      }
      if (status == 429) {
        return ProviderError(
          code: InkErrorCode.providerBusy,
          extra: {...extra, 'status': status},
          cause: e,
        );
      }
      if (status >= 500) {
        return ProviderError(
          code: InkErrorCode.providerServer,
          extra: {...extra, 'status': status},
          cause: e,
        );
      }
      return ProviderError(
        code: InkErrorCode.invalidParameter,
        extra: {...extra, 'status': status, ..._bodyBrief(e.response?.data)},
        cause: e,
      );
  }
}

// 响应体只保留截断后的 code / message 摘要，绝不携带原始 body
// （原始 body 可能回显 api key / prompt 等敏感内容）。
Map<String, Object?> _bodyBrief(Object? data) {
  if (data == null) return const <String, Object?>{};
  if (data is Map) {
    final err = data['error'];
    final Map<dynamic, dynamic> inner = err is Map ? err : data;
    final code = inner['code'] ?? inner['error_code'];
    final message = inner['message'] ?? inner['msg'];
    return <String, Object?>{
      if (code != null) 'body_code': _clip(code.toString(), 100),
      if (message != null) 'body_message': _clip(message.toString(), 300),
    };
  }
  return <String, Object?>{'body_message': _clip(data.toString(), 300)};
}

String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);
