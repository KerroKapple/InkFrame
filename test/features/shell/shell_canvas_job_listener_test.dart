// 画布侧的 job 监听（CanvasJobListener）挂在外壳根（InkShell），不随画布页挂载。
//
// 没开画布时（画布页从没物化）job 照样在跑；任务弹层这类全局界面会保活 job 所在画布的节点控制器（任务名、
// 「定位」都靠它找源节点）。那张画布上的 job 成功 ⇒ 它的控制器照样重新读库，读到落了产物的那一行。监听要是
// 跟着画布页挂载，这段时间落的产物就没人让控制器失效，「定位」过去看到的还是没有产物的占位。
// 监听本身的判据（哪些 job、哪张画布）见 test/features/canvas/widgets/canvas_screen_job_listener_test.dart。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_screen.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';

import '../../_harness/fake_repositories.dart';
import '../../_harness/fake_toast_service.dart';
import '../../_harness/shell_app.dart';

/// 按画布记读了几次库的内存节点仓储。
class _CountingNodeRepository extends InMemoryNodeRepository {
  final Map<String, int> reads = <String, int>{};

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) {
    reads[canvasId] = (reads[canvasId] ?? 0) + 1;
    return super.listByCanvas(canvasId);
  }
}

void main() {
  testWidgets('没开画布时 job 成功：job 所在画布被保活的节点控制器照样重新读库，读到带产物的新状态', (tester) async {
    final _CountingNodeRepository nodes = _CountingNodeRepository();
    // cvB 上一张图像配置 + 一个还在生成的产物占位（还没有 image_url）。
    final String cfg = await nodes.create(canvasId: 'cvB', type: 'image', nodeRole: 'config', label: 'Peaks');
    final String result = await nodes.create(
      canvasId: 'cvB',
      type: 'image',
      nodeRole: 'result',
      sourceNodeId: cfg,
    );
    final paths = await setupTempPaths(tester, 'ink_shell_job_listener_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(project: ProjectRef(id: 'p1', name: 'Alpha')),
      extraOverrides: <Override>[
        nodeRepositoryProvider.overrideWith((_) async => nodes),
        // job 成功会弹通知卡（卡片带计时器）：换成只记录的假实现。
        toastServiceProvider.overrideWithValue(RecordingToastService()),
      ],
    );
    expect(find.byType(CanvasScreen), findsNothing, reason: '前提：没开画布，画布页从没物化');

    // 任务弹层这类全局界面保活着 cvB 的节点控制器。
    final ProviderContainer c = readShellContainer(tester);
    final ProviderSubscription<AsyncValue<List<CanvasNode>>> hold =
        c.listen(canvasNodesControllerProvider('cvB'), (_, _) {});
    addTearDown(hold.close);
    c.read(jobsRegistryProvider.notifier).upsert(
          JobState.running(
            jobId: 'jb',
            providerId: 'p',
            canvasId: 'cvB',
            sourceNodeId: cfg,
            resultNodeId: result,
            progress: 0.5,
          ),
        );
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }
    final int readsBefore = nodes.reads['cvB'] ?? 0;
    expect(readsBefore, greaterThan(0), reason: '前提：cvB 的控制器已经读过一次库');
    expect(
      hold.read().requireValue.firstWhere((CanvasNode n) => n.id == result).imageUrl,
      isNull,
      reason: '前提：读到的是还没有产物的占位',
    );

    // 产物落库（result 有了 image_url），然后 job 转成功。
    await nodes.patchTypeConfig(result, <String, Object?>{'image_url': 'images/peaks.png'});
    c.read(jobsRegistryProvider.notifier).upsert(
          JobState.succeeded(
            jobId: 'jb',
            providerId: 'p',
            canvasId: 'cvB',
            sourceNodeId: cfg,
            resultNodeId: result,
            artifactPath: 'images/peaks.png',
          ),
        );
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(nodes.reads['cvB'], greaterThan(readsBefore), reason: '画布页不在，外壳根的监听照样让 cvB 的控制器失效');
    expect(
      hold.read().requireValue.firstWhere((CanvasNode n) => n.id == result).imageUrl,
      'images/peaks.png',
      reason: '「定位」过去要看到产物，不是旧的占位',
    );
  });
}
