import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/providers/dio_error_mapper.dart';

RequestOptions _ro() => RequestOptions(path: '/x');

DioException _typed(DioExceptionType t) =>
    DioException(requestOptions: _ro(), type: t);

DioException _badResponse(int status) => DioException(
      requestOptions: _ro(),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(requestOptions: _ro(), statusCode: status),
    );

void main() {
  test('连接/发送/接收超时 → networkTimeout', () {
    for (final t in <DioExceptionType>[
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      final err = mapDioError(_typed(t), providerId: 'p');
      expect(err, isA<NetworkError>());
      expect(err.code, InkErrorCode.networkTimeout);
    }
  });

  test('connectionError → networkOffline', () {
    final err = mapDioError(_typed(DioExceptionType.connectionError), providerId: 'p');
    expect(err.code, InkErrorCode.networkOffline);
  });

  test('cancel → CancelledError', () {
    final err = mapDioError(_typed(DioExceptionType.cancel), providerId: 'p');
    expect(err, isA<CancelledError>());
  });

  test('401 / 403 → invalidKey', () {
    for (final s in <int>[401, 403]) {
      final err = mapDioError(_badResponse(s), providerId: 'p');
      expect(err, isA<ProviderError>());
      expect(err.code, InkErrorCode.invalidKey);
    }
  });

  test('402 → insufficientBalance', () {
    expect(mapDioError(_badResponse(402), providerId: 'p').code,
        InkErrorCode.insufficientBalance);
  });

  test('429 → providerBusy', () {
    expect(mapDioError(_badResponse(429), providerId: 'p').code,
        InkErrorCode.providerBusy);
  });

  test('5xx → providerServer', () {
    expect(mapDioError(_badResponse(503), providerId: 'p').code,
        InkErrorCode.providerServer);
  });

  test('其它 4xx → invalidParameter', () {
    expect(mapDioError(_badResponse(400), providerId: 'p').code,
        InkErrorCode.invalidParameter);
  });

  test('badResponse body 只留截断 code/message，不携带原始响应体', () {
    final e = DioException(
      requestOptions: _ro(),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: _ro(),
        statusCode: 400,
        data: <String, Object?>{
          'error': <String, Object?>{
            'code': 'invalid_request',
            'message': 'm' * 1000,
          },
          'echo_key': 'sk-raw-body-secret-000111',
        },
      ),
    );
    final err = mapDioError(e, providerId: 'p');
    expect(err.extra.containsKey('body'), isFalse);
    expect(err.extra['body_code'], 'invalid_request');
    expect((err.extra['body_message'] as String).length,
        lessThanOrEqualTo(300));
    expect(err.extra.toString().contains('sk-raw-body-secret-000111'),
        isFalse);
  });

  test('badResponse 非 Map body → 截断字符串摘要', () {
    final e = DioException(
      requestOptions: _ro(),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: _ro(),
        statusCode: 422,
        data: 'plain failure text ${'x' * 1000}',
      ),
    );
    final err = mapDioError(e, providerId: 'p');
    expect(err.extra.containsKey('body'), isFalse);
    expect((err.extra['body_message'] as String).length,
        lessThanOrEqualTo(300));
  });

  test('providerId 写入 extra', () {
    final err = mapDioError(_badResponse(429), providerId: 'wanx-image');
    expect(err.extra['provider_id'], 'wanx-image');
  });
}
