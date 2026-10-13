// Provider 失败的日志出口（GAP-3 评审 P3③）。
//
// 由来：错误上屏统一走 `l10nAsyncError`，它把**非 InkError** 一律映射成
// `errorUnknown`。那是刻意的——raw toString 不该上屏（GAP-3 定下的规矩，
// `InkError(local_io_error, …)` 这种东西给用户看没有意义）。但代价是：真出现
// 非 InkError 时，用户看到一句泛泛的话，日志里**什么都没有**，报障等于没线索。
// 换文案之前的 raw toString 至少还能让用户截个图。
//
// 为什么挂在 `ProviderObserver` 而不是各个 widget 的 error 分支：失败是 provider
// 的事实，和「哪个 widget 恰好渲染了它」无关。同一个错可能被三个 widget 同时
// 渲染（那样会记三次），也可能一个都没渲染（那样就彻底消失了）。观察者这一层
// 与渲染无关，恰好记一次。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/ink_error.dart';
import '../core/logging/logger_service.dart';

const String _kModule = 'app.provider';

class ProviderFailureLogger extends ProviderObserver {
  const ProviderFailureLogger(this._logger);

  final LoggerService _logger;

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _logger.error(
      _kModule,
      'provider failed',
      extra: <String, Object?>{
        // 本仓所有 provider 都带 `name:`（`core/di` 与各 feature 的约定），
        // 兜底用类型名——无名 provider 也总比记不出是谁好。
        'provider': provider.name ?? provider.runtimeType.toString(),
        // 这一项是整条日志的核心：上屏文案被归一成 errorUnknown 之后，错误类型
        // 是唯一还能区分「到底什么坏了」的东西。
        'error_type': error.runtimeType.toString(),
        'is_ink_error': error is InkError,
        if (error is InkError) 'code': error.code.wire,
      },
      // cause / stackTrace 由 logger 自己截断并递归脱敏后并入（见
      // logger_service 的 _redact），这里不预处理。
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
