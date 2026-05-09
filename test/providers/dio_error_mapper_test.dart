import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/providers/dio_error_mapper.dart';

void main() {
  final testCases = [
    (
      name: 'connection timeout',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      ),
      expectedType: NetworkError,
      expectedCode: InkErrorCode.networkTimeout,
    ),

    (
      name: 'send timeout',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.sendTimeout,
      ),
      expectedType: NetworkError,
      expectedCode: InkErrorCode.networkTimeout,
    ),

    (
      name: 'receive timeout',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.receiveTimeout,
      ),
      expectedType: NetworkError,
      expectedCode: InkErrorCode.networkTimeout,
    ),

    (
      name: 'connection error',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      ),
      expectedType: NetworkError,
      expectedCode: InkErrorCode.networkOffline,
    ),

    (
      name: 'bad certificate',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badCertificate,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          data: {'reason': 'bad_certificate'},
        ),
      ),
      expectedType: NetworkError,
      expectedCode: InkErrorCode.networkOffline,
    ),

    (
      name: 'cancel',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.cancel,
      ),
      expectedType: CancelledError,
      expectedCode: InkErrorCode.cancelledByUser,
    ),

    (
      name: 'unknown',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.unknown,
      ),
      expectedType: UnknownError,
      expectedCode: InkErrorCode.unknown,
    ),

    (
      name: '401 invalid key',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 401,
        ),
      ),
      expectedType: ProviderError,
      expectedCode: InkErrorCode.invalidKey,
    ),

    (
      name: '403 invalid key',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 403,
        ),
      ),
      expectedType: ProviderError,
      expectedCode: InkErrorCode.invalidKey,
    ),

    (
      name: '402 insufficient balance',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 402,
        ),
      ),
      expectedType: ProviderError,
      expectedCode: InkErrorCode.insufficientBalance,
    ),

    (
      name: '429 provider busy',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 429,
        ),
      ),
      expectedType: ProviderError,
      expectedCode: InkErrorCode.providerBusy,
    ),

    (
      name: '500 provider server',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 500,
        ),
      ),
      expectedType: ProviderError,
      expectedCode: InkErrorCode.providerServer,
    ),

    (
      name: 'other 4xx invalid parameter',
      exception: DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 418,
        ),
      ),
      expectedType: ProviderError,
      expectedCode: InkErrorCode.invalidParameter,
    ),
  ];

  group('mapDioError', () {
    for (final testCase in testCases) {
      test(testCase.name, () {
        final result = mapDioError(
          testCase.exception,
          providerId: 'test_provider',
        );

        expect(result.runtimeType, testCase.expectedType);
        expect(result.code, testCase.expectedCode);
        expect(result.extra['provider_id'], 'test_provider');
      });
    }
  });
}
