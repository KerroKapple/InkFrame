// GithubUpdateCheckService：基于 GitHub Releases API 的更新检查（UPD-1）。
//
// 刻意不用 /releases/latest——该端点不含 prerelease（alpha/beta 阶段全是 prerelease,
// 现网 latest 即错挂旧版）;改拉 /releases?per_page=10 全列表,跳过 draft 与
// 非 semver tag,按 SemVer 序自取最大再与本机比较（alpha.10 > alpha.9 数值序）。
//
// 错误契约：只抛 InkError——超时/断网 → NetworkError;403/429（匿名限流 60/h）→
// providerBusy;其余非 2xx → providerServer;响应体非列表 → providerInvalidResponse;
// 本机版本不可解析 → UnknownError。业务层看不到裸 DioException。
import 'package:dio/dio.dart';

import '../core/errors/ink_error.dart';
import '../core/interfaces/update_check_service.dart';
import '../core/models/semver.dart';
import '../core/models/update_check_result.dart';

class GithubUpdateCheckService implements UpdateCheckService {
  GithubUpdateCheckService({
    required Dio dio,
    required Future<String> Function() versionSource,
    String repoSlug = 'KerroKapple/InkFrame',
  })  : _dio = dio,
        _versionSource = versionSource,
        _repoSlug = repoSlug;

  final Dio _dio;
  final Future<String> Function() _versionSource;
  final String _repoSlug;

  static const int _perPage = 10;

  @override
  Future<UpdateCheckResult> check() async {
    final String rawVersion = await _versionSource();
    final SemVer? current = SemVer.tryParse(rawVersion);
    if (current == null) {
      throw UnknownError(
        cause: FormatException('unparseable current version', rawVersion),
        extra: const <String, Object?>{'source': 'update_check'},
      );
    }

    final Object? body = await _fetchReleases();
    if (body is! List) {
      throw const ProviderError(
        code: InkErrorCode.providerInvalidResponse,
        extra: <String, Object?>{
          'source': 'update_check',
          'reason': 'body_not_list',
        },
      );
    }

    SemVer? best;
    String? bestUrl;
    for (final Object? item in body) {
      if (item is! Map) continue;
      if (item['draft'] == true) continue;
      final Object? tag = item['tag_name'];
      if (tag is! String) continue;
      final SemVer? version = SemVer.tryParse(tag);
      if (version == null) continue;
      if (best == null || version.compareTo(best) > 0) {
        best = version;
        bestUrl = _httpsUrlOrNull(item['html_url']);
      }
    }

    if (best == null || best.compareTo(current) <= 0) {
      return UpdateCheckResult(currentVersion: current.toString());
    }
    return UpdateCheckResult(
      currentVersion: current.toString(),
      latestVersion: best.toString(),
      releaseUrl: bestUrl,
    );
  }

  Future<Object?> _fetchReleases() async {
    try {
      final Response<Object?> resp = await _dio.get<Object?>(
        '/repos/$_repoSlug/releases',
        queryParameters: const <String, Object?>{'per_page': _perPage},
        options: Options(
          headers: const <String, Object?>{
            'Accept': 'application/vnd.github+json',
          },
        ),
      );
      return resp.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// GitHub API 专用映射——不复用 mapDioError：403 在 GitHub 语义是匿名限流
  /// 而非 invalidKey,错挂会把「稍后再试」显示成「API Key 无效」。
  static InkError _mapDioError(DioException e) {
    const extra = <String, Object?>{'source': 'update_check'};
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
      case DioExceptionType.badCertificate:
        return NetworkError(
          code: InkErrorCode.networkOffline,
          extra: extra,
          cause: e,
        );
      case DioExceptionType.cancel:
        return const CancelledError.byUser(extra: extra);
      case DioExceptionType.unknown:
        return UnknownError(cause: e, extra: extra, stackTrace: e.stackTrace);
      case DioExceptionType.badResponse:
        final int status = e.response?.statusCode ?? 0;
        return ProviderError(
          code: status == 403 || status == 429
              ? InkErrorCode.providerBusy
              : InkErrorCode.providerServer,
          extra: <String, Object?>{...extra, 'status': status},
          cause: e,
        );
    }
  }

  static String? _httpsUrlOrNull(Object? url) {
    if (url is! String) return null;
    final Uri? parsed = Uri.tryParse(url);
    if (parsed == null || parsed.scheme != 'https') return null;
    return url;
  }
}
