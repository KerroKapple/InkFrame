// FakeProcessStarter/FakeStartedProcess 契约自测（评审 P2-6/P2-7）：
// 与 _SystemRunningProcess 的关键语义钉死，防共享 fake 漂移骗绿。
import 'package:flutter_test/flutter_test.dart';

import 'fake_process.dart';

void main() {
  test('exitCode 完成不依赖 stdout 被订阅（真进程语义）', () async {
    final p = FakeStartedProcess(exit: 7, stderr: '', hang: false);
    // 从未 listen stdoutLines——exitCode 仍须完成。
    expect(await p.exitCode, 7);
  });

  test('hang=true：exitCode 悬置直到 kill；kill 幂等收 -15', () async {
    final p = FakeStartedProcess(exit: 0, stderr: '', hang: true);
    var done = false;
    // ignore: unawaited_futures
    p.exitCode.then((_) => done = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(done, isFalse, reason: '挂死进程不自行退出');

    p.kill();
    p.kill(); // 幂等
    expect(await p.exitCode, -15);
  });

  test('killCompletesExit=false：kill 只记账，流照常收尾 exit 按配置完成', () async {
    final p = FakeStartedProcess(
      exit: 0,
      stderr: '',
      hang: false,
      killCompletesExit: false,
      exitDelay: const Duration(milliseconds: 30),
    );
    p.kill();
    expect(p.killed, isTrue);
    expect(await p.exitCode, 0, reason: 'kill 无效——按自然退出码完成');
  });

  test('starter 捕获 exe/args/env 且 throwOnStart 抛 ProcessException', () async {
    final s = FakeProcessStarter(writesOutput: false);
    await s.start('exe', const <String>['-a'],
        environment: const <String, String>{'K': 'V'});
    expect(s.calls, 1);
    expect(s.lastExecutable, 'exe');
    expect(s.lastArgs, const <String>['-a']);
    expect(s.lastEnv, const <String, String>{'K': 'V'});
  });
}
