// SerialMutationQueue 单测 —— 锁定"尾不中毒"契约：某 op 抛出非 InkError 时，
// 错误只回流给该 op 自己的调用方，队列尾仍常态完成，后续排队 op 照常执行。
//
// 这正是 serialize 用宽捕获而非 `on InkError` 收窄的原因：收窄会让 _tail 以错误态完成，
// 后续所有变更永久挂起。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/serial_mutation_queue.dart';

class _Harness with SerialMutationQueue {}

void main() {
  test('非 InkError 抛出不毒化队列尾：首个调用方拿到错误，后续 op 照常执行且严格串行', () async {
    final q = _Harness();
    final ran = <String>[];

    // op1 抛非 InkError（StateError）——若 serialize 用 `on InkError` 收窄，
    // 这里会让 _tail 以错误态完成，f2 将永远挂起。
    final f1 = q.serialize<void>(() async {
      ran.add('op1');
      throw StateError('boom');
    });
    // op2 排在 op1 之后，应正常跑完。
    final f2 = q.serialize<int>(() async {
      ran.add('op2');
      return 42;
    });

    await expectLater(f1, throwsA(isA<StateError>()),
        reason: '错误只回流给抛出它的那个 op 的调用方');
    expect(await f2, 42, reason: '前一 op 抛非 InkError 不得挂起后续 op');
    expect(ran, <String>['op1', 'op2'], reason: '严格串行：op2 在 op1 完成之后才跑');
  });
}
