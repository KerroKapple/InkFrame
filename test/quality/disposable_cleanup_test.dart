// 生命周期铁律回归：把原 check-disposable-cleanup.sh 固化为 Dart 静态测试。
//
// 铁律（docs/CLAUDE.md §IoC & Lifecycle）：创建即销毁——StreamSubscription /
// TextEditingController / AnimationController / FocusNode / Timer / ScrollController /
// 捕获式 ref.listen 订阅，必须在 dispose() / ref.onDispose() 里释放，否则内存泄漏。
//
// 文件级近似（与原脚本同语义）：若文件创建了某类资源，则要求同文件出现对应的
// .dispose() / .cancel() 释放调用即视为达标。这是回归靶子而非精确数据流分析——
// 目标是拦住"建了忘释放"的整类回归。
//
// 覆盖原脚本 7 类规则，并修正其两处过严误报：
//   - ref.listen：仅当结果被【捕获进变量】(final sub = ref.listen) 且无 onDispose/close
//     才算违例；build() 内裸 ref.listen(...) 由 Riverpod 自动随 widget 释放，不报
//     （原脚本对所有 ref.listen 强求 onDispose → canvas_view / canvas_job_listener 假阳）。
//   - 其余规则保持文件级"创建 ↔ 释放"配对语义。
//
// 删除 check-disposable-cleanup.sh 后，本测试是生命周期铁律的回归靶子。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.endsWith('_test.dart') ||
    p.contains('l10n/generated/') ||
    p.contains('generated/');

void main() {
  // 资源创建模式。
  final createStreamSub =
      RegExp(r'late\s+StreamSubscription|StreamSubscription[<\s][^;]*=');
  final createTextCtrl = RegExp(r'TextEditingController\s*\(\s*\)');
  final createAnimCtrl = RegExp(r'AnimationController\s*\(');
  final createFocusNode = RegExp(r'FocusNode\s*\(\s*\)');
  final createScrollCtrl = RegExp(r'ScrollController\s*\(');
  final createTimer = RegExp(r'Timer\.(periodic|new)\s*\(|=\s*Timer\s*\(');
  // ref.listen 仅当结果被捕获进变量才需手动释放（泄漏真模式）。
  final capturedListen =
      RegExp(r'(final|var)\s+\w+\s*=\s*ref\.listen\s*[<(]');

  // 释放模式（文件级存在性）。
  final hasDispose = RegExp(r'\.dispose\s*\(\s*\)');
  final hasCancel = RegExp(r'\.cancel\s*\(\s*\)');
  final hasOnDispose = RegExp(r'ref\.onDispose');
  final hasClose = RegExp(r'\.close\s*\(');
  final hasDisposeMethod = RegExp(r'void\s+dispose\s*\(\s*\)');

  test('lib 下可释放资源均有对应释放（dispose/cancel/onDispose）（生命周期铁律）',
      () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ not found');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (_isGenerated(path)) continue;

      final content = entity.readAsStringSync();
      final lines = content.split('\n');

      // 文件级释放能力（一次性计算）。
      final fileHasDispose = hasDispose.hasMatch(content);
      final fileHasCancel = hasCancel.hasMatch(content);
      final fileHasOnDispose = hasOnDispose.hasMatch(content);
      final fileHasClose = hasClose.hasMatch(content);
      final fileHasDisposeMethod = hasDisposeMethod.hasMatch(content);

      for (var i = 0; i < lines.length; i++) {
        final raw = lines[i];
        final trimmed = raw.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        final at = '$path:${i + 1}';

        // R1：StreamSubscription 未 cancel。
        if (createStreamSub.hasMatch(raw) && !fileHasCancel) {
          violations.add(
            '$at  [R1 STREAM_SUBSCRIPTION_LEAK] StreamSubscription 创建但本文件无 '
            '.cancel()；在 dispose()/ref.onDispose 里取消：${raw.trim()}',
          );
        }

        // R2：TextEditingController 未 dispose（缺 dispose 方法或缺 .dispose 调用）。
        if (createTextCtrl.hasMatch(raw) &&
            (!fileHasDisposeMethod || !fileHasDispose)) {
          violations.add(
            '$at  [R2 CONTROLLER_NOT_DISPOSED] TextEditingController 创建但无 '
            '.dispose()；在 State.dispose() 里释放：${raw.trim()}',
          );
        }

        // R3：AnimationController 未 dispose。
        if (createAnimCtrl.hasMatch(raw) &&
            (!fileHasDisposeMethod || !fileHasDispose)) {
          violations.add(
            '$at  [R3 ANIMATION_CONTROLLER_LEAK] AnimationController 创建但无 '
            '.dispose()：${raw.trim()}',
          );
        }

        // R4：FocusNode 未 dispose。
        if (createFocusNode.hasMatch(raw) &&
            (!fileHasDisposeMethod || !fileHasDispose)) {
          violations.add(
            '$at  [R4 FOCUS_NODE_LEAK] FocusNode 创建但无 .dispose()：'
            '${raw.trim()}',
          );
        }

        // R5：ScrollController 未 dispose。
        if (createScrollCtrl.hasMatch(raw) &&
            (!fileHasDisposeMethod || !fileHasDispose)) {
          violations.add(
            '$at  [R5 SCROLL_CONTROLLER_LEAK] ScrollController 创建但无 '
            '.dispose()：${raw.trim()}',
          );
        }

        // R6：Timer 未 cancel。
        if (createTimer.hasMatch(raw) && !fileHasCancel) {
          violations.add(
            '$at  [R6 TIMER_NOT_CANCELLED] Timer 创建但本文件无 .cancel()；'
            '在 dispose()/ref.onDispose 里取消：${raw.trim()}',
          );
        }

        // R7：捕获式 ref.listen 未释放（裸 build 内 ref.listen 自动管理，不报）。
        if (capturedListen.hasMatch(raw) &&
            !fileHasOnDispose &&
            !fileHasClose) {
          violations.add(
            '$at  [R7 RIVERPOD_LISTENER_LEAK] 捕获式 ref.listen 订阅未释放；'
            'final sub = ref.listen(...); ref.onDispose(sub.close)：'
            '${raw.trim()}',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '资源泄漏（创建但未释放）：\n${violations.join('\n')}',
    );
  });
}
