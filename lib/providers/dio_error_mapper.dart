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
        extra: {...extra, 'status': status, 'body': e.response?.data},
        cause: e,
      );
  }
}
