import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';

void main() {
  group('InkErrorCode wire values', () {
    test('14 codes match PRD §10.6 string wire format', () {
      expect(InkErrorCode.values.length, 14);
      expect(InkErrorCode.invalidKey.wire, 'invalid_key');
      expect(InkErrorCode.insufficientBalance.wire, 'insufficient_balance');
      expect(InkErrorCode.contentPolicy.wire, 'content_policy');
      expect(InkErrorCode.invalidParameter.wire, 'invalid_parameter');
      expect(InkErrorCode.networkTimeout.wire, 'network_timeout');
      expect(InkErrorCode.networkOffline.wire, 'network_offline');
      expect(InkErrorCode.providerServer.wire, 'provider_5xx');
      expect(InkErrorCode.providerBusy.wire, 'provider_busy');
      expect(InkErrorCode.pollTimeout.wire, 'poll_timeout');
      expect(InkErrorCode.downloadFailed.wire, 'download_failed');
      expect(InkErrorCode.localIOError.wire, 'local_io_error');
      expect(InkErrorCode.cancelledByUser.wire, 'cancelled_by_user');
      expect(InkErrorCode.cancelledOnExit.wire, 'cancelled_on_exit');
      expect(InkErrorCode.unknown.wire, 'unknown');
    });

    test('fromWire round-trips all codes', () {
      for (final c in InkErrorCode.values) {
        expect(InkErrorCode.fromWire(c.wire), c);
      }
    });

    test('fromWire falls back to unknown on garbage', () {
      expect(InkErrorCode.fromWire('not_a_real_code'), InkErrorCode.unknown);
    });
  });

  group('retryable whitelist matches PRD §10.6', () {
    const retryableCodes = <InkErrorCode>{
      InkErrorCode.networkTimeout,
      InkErrorCode.networkOffline,
      InkErrorCode.providerServer,
      InkErrorCode.providerBusy,
      InkErrorCode.downloadFailed,
    };

    test('only the 5 whitelisted codes are retryable', () {
      for (final c in InkErrorCode.values) {
        final err = c == InkErrorCode.downloadFailed
            ? const DownloadError()
            : c == InkErrorCode.localIOError
                ? const LocalIOError()
                : c == InkErrorCode.cancelledByUser
                    ? const CancelledError.byUser()
                    : c == InkErrorCode.cancelledOnExit
                        ? const CancelledError.onExit()
                        : c == InkErrorCode.unknown
                            ? const UnknownError(cause: 'boom')
                            : c == InkErrorCode.networkTimeout ||
                                    c == InkErrorCode.networkOffline
                                ? NetworkError(code: c)
                                : ProviderError(code: c);
        expect(err.retryable, retryableCodes.contains(c), reason: 'code=$c');
      }
    });
  });

  group('messageKey resolution', () {
    test('every code resolves to an ARB key', () {
      for (final c in InkErrorCode.values) {
        final err = c == InkErrorCode.downloadFailed
            ? const DownloadError()
            : c == InkErrorCode.localIOError
                ? const LocalIOError()
                : c == InkErrorCode.cancelledByUser
                    ? const CancelledError.byUser()
                    : c == InkErrorCode.cancelledOnExit
                        ? const CancelledError.onExit()
                        : c == InkErrorCode.unknown
                            ? const UnknownError(cause: 'x')
                            : c == InkErrorCode.networkTimeout ||
                                    c == InkErrorCode.networkOffline
                                ? NetworkError(code: c)
                                : ProviderError(code: c);
        expect(err.messageKey, isNotEmpty);
        expect(err.messageKey.startsWith('error'), isTrue);
      }
    });
  });

  group('subclass assertions', () {
    test('NetworkError rejects non-network code', () {
      expect(
        () => NetworkError(code: InkErrorCode.invalidKey),
        throwsA(isA<AssertionError>()),
      );
    });

    test('ProviderError rejects network code', () {
      expect(
        () => ProviderError(code: InkErrorCode.networkTimeout),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('toLogJson', () {
    test('serializes wire code + retryable + extra', () {
      final err = NetworkError(
        code: InkErrorCode.networkTimeout,
        extra: const <String, Object?>{'host': 'api.klingai.com'},
      );
      final json = err.toLogJson();
      expect(json['code'], 'network_timeout');
      expect(json['retryable'], true);
      expect(json['extra'], <String, Object?>{'host': 'api.klingai.com'});
    });
  });
}
