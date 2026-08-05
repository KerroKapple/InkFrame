# EX-3 导出进度+取消 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 视频导出获得真实进度显示与取消能力；ProcessRunner 获得流式通道（PR-2 备份/还原超时复用）；顺带收 BOARD 债144 两件（失败提示改内嵌 banner、同名覆盖警示）。

**Architecture:** 新增 `ProcessStarter`/`RunningProcess` 流式接口（ISP：与一次性 `run()` 分离，既有 fake 零改动）；`FfmpegVideoExportService.concat` 改流式执行并解析 `-progress pipe:1` 的 `out_time_ms`（**名为 ms 实为微秒**，ffmpeg 已知怪癖）；取消 = token→kill→清半成品→`CancelledError.byUser`；控制器把进度/取消透传给对话框。

**Tech Stack:** Dart/Flutter，dart:io Process.start，Riverpod AutoDisposeNotifier，既有 InkProgressBar（已支持 determinate value）/InkErrorBanner(message:)。

## Global Constraints

- flutter 命令一律绝对路径：`C:\Users\Kerro\flutter\bin\flutter.bat`（PLAYBOOK §2.1）
- 分支 `feat/ex3-export-progress-cancel`；main 禁直接提交；conventional commits
- TDD 先红后绿；禁 catch Exception/dynamic（不变量#8）；ARB en/zh 同 commit（#12）
- 全量测试白名单：仅允许 node_card_golden_test 3 个 Windows 假阳性；skip 基线 ≈46（新增 ffmpeg 门控测 +1）
- 禁全量 build_runner（本 PR 无 freezed 模型改动，不需要）
- 完成状态记 BOARD/MASTERPLAN，不回写冻结 plan

---

### Task 1: ProcessStarter + RunningProcess 接口与系统实现

**Files:**
- Modify: `lib/core/interfaces/process_runner.dart`（追加两个抽象）
- Modify: `lib/services/system_process_runner.dart`（implements 两接口）
- Test: 无独立测试（thin dart:io 胶水，与现 run() 同待遇；行为由 Task 5 真 ffmpeg 集成测覆盖）

**Interfaces（Produces，后续 Task 依赖）:**
```dart
abstract class RunningProcess {
  Stream<String> get stdoutLines;   // utf8 按行；单订阅
  Future<int> get exitCode;         // 完成时 stderr 已排干
  String get stderrTail;            // 尾部 ≤4000 字符
  void kill();                      // 幂等
}
abstract class ProcessStarter {
  Future<RunningProcess> start(String executable, List<String> arguments,
      {Map<String, String>? environment});
}
```

- [ ] **Step 1: 接口追加**（process_runner.dart 文件尾）——上面签名照抄，doc 注释说明：ISP 分离理由（只有进度/取消消费方依赖流式）、kill 平台语义（Windows TerminateProcess / POSIX SIGTERM）、失败语义与 run() 一致抛 ProcessException。
- [ ] **Step 2: SystemProcessRunner 实现**：

```dart
class SystemProcessRunner implements ProcessRunner, ProcessStarter {
  const SystemProcessRunner();

  @override
  Future<ProcessResult> run(...) => ...; // 现状不动

  @override
  Future<RunningProcess> start(String executable, List<String> arguments,
      {Map<String, String>? environment}) async {
    final p = await Process.start(executable, arguments,
        environment: environment);
    return _SystemRunningProcess(p);
  }
}

class _SystemRunningProcess implements RunningProcess {
  _SystemRunningProcess(this._p) {
    // stderr 必须持续排干，否则管道背压可能挂死进程（Windows 尤甚）。
    _stderrDone = _p.stderr.transform(utf8.decoder).forEach((chunk) {
      _buf.write(chunk);
      if (_buf.length > _kCap) {
        final s = _buf.toString();
        _buf..clear()..write(s.substring(s.length - _kCap));
      }
    });
  }
  static const int _kCap = 4000;
  final Process _p;
  final StringBuffer _buf = StringBuffer();
  late final Future<void> _stderrDone;

  @override
  Stream<String> get stdoutLines =>
      _p.stdout.transform(utf8.decoder).transform(const LineSplitter());

  @override
  Future<int> get exitCode async {
    final code = await _p.exitCode;
    try { await _stderrDone; } on Object { /* 解码失败不掩盖退出码 */ }
    return code;
  }

  @override
  String get stderrTail => _buf.toString();

  @override
  void kill() => _p.kill();
}
```

- [ ] **Step 3: analyze 过**：`C:\Users\Kerro\flutter\bin\flutter.bat analyze lib test` 0 issue。
- [ ] **Step 4: Commit** `feat(core): ProcessStarter/RunningProcess 流式进程通道（EX-3 前置）`

### Task 2: concat 流式重写 + 进度解析 + 取消（TDD 核心）

**Files:**
- Modify: `lib/core/interfaces/video_export_service.dart`（签名扩参 + ExportCancelToken）
- Modify: `lib/services/ffmpeg_video_export_service.dart`（流式重写）
- Modify: `lib/core/di/video_export.dart`（注入 processStarter）
- Test: `test/services/ffmpeg_video_export_service_test.dart`（扩展既有；FakeRunningProcess/FakeProcessStarter 建在本文件，若既有 fake 在 _harness 则跟随其位置惯例）

**Interfaces（Produces）:**
```dart
class ExportCancelToken {
  bool get isCancelled;
  void cancel();                          // 幂等；已 attach 则立即触发
  void attach(void Function() onCancel);  // 服务侧注册；已取消则立即回调
}
// concat 新签名（既有三参不变，追加）：
Future<String> concat({
  required String projectId,
  required List<String> inputRelativePaths,
  String? outputBaseName,
  int? totalDurationMs,                    // null/<=0 → 不回调（indeterminate）
  void Function(double progress)? onProgress, // 0..1，单调不回退
  ExportCancelToken? cancelToken,
});
```

- [ ] **Step 1: 失败测试组一——参数序列**。Fake：

```dart
class FakeRunningProcess implements RunningProcess {
  FakeRunningProcess({required this.lines, required this.exit, this.stderr = ''});
  final List<String> lines;
  final int exit;
  final String stderr;
  bool killed = false;
  final Completer<int> _exit = Completer<int>();
  late final StreamController<String> _ctrl = StreamController<String>(
    onListen: () async {
      for (final l in lines) { _ctrl.add(l); await Future<void>.delayed(Duration.zero); }
      if (!killed) { await _ctrl.close(); _exit.complete(exit); }
    },
  );
  @override Stream<String> get stdoutLines => _ctrl.stream;
  @override Future<int> get exitCode => _exit.future;
  @override String get stderrTail => stderr;
  @override void kill() {
    if (killed) return;
    killed = true;
    _ctrl.close();
    _exit.complete(-15);
  }
}
class FakeProcessStarter implements ProcessStarter {
  FakeProcessStarter(this.next);
  final FakeRunningProcess next;
  List<String>? capturedArgs;
  String? capturedExe;
  @override Future<RunningProcess> start(String executable, List<String> arguments,
      {Map<String, String>? environment}) async {
    capturedExe = executable; capturedArgs = arguments;
    return next;
  }
}
```

测试断言 args 精确序列：`['-f','concat','-safe','0','-i',<list>,'-c','copy','-progress','pipe:1','-nostats','-y',<out>]`。
- [ ] **Step 2: 跑红**：`flutter.bat test test/services/ffmpeg_video_export_service_test.dart` — 新用例因 concat 无新参编译失败或断言失败。
- [ ] **Step 3: 接口与服务实现**。要点：
  - `ExportCancelToken` 定义在 video_export_service.dart（`_onCancel` 单监听 assert）。
  - 服务构造加 `required ProcessStarter processStarter`；`_runFfmpeg` 改：

```dart
final running = await _startFfmpeg(ffmpeg, listFile, outputFile); // ProcessException→invalidate+ffmpeg_not_found（现逻辑保留）
cancelToken?.attach(running.kill);
final totalUs = (totalDurationMs != null && totalDurationMs > 0) ? totalDurationMs * 1000 : null;
var last = 0.0;
await for (final line in running.stdoutLines) {
  if (totalUs == null || onProgress == null) continue;
  final p = parseProgressLine(line, totalDurationUs: totalUs, last: last);
  if (p != null) { last = p; onProgress(p); }
}
final code = await running.exitCode;
if (cancelToken?.isCancelled ?? false) {
  _deleteIfExists(outputFile);
  throw const CancelledError.byUser(extra: <String, Object?>{'reason': 'export_cancelled'});
}
if (code != 0) { _deleteIfExists(outputFile); throw LocalIOError(... stderr: _tail(running.stderrTail)); }
if (onProgress != null && totalUs != null) onProgress(1.0);  // 成功强制收口到 1
```

  - 解析器（static，直接单测）：

```dart
/// -progress 键值行解析。out_time_ms 实为微秒；负值/乱码/回退值返回 null。
static double? parseProgressLine(String line,
    {required int totalDurationUs, required double last}) {
  final m = RegExp(r'^out_time_ms=(-?\d+)$').firstMatch(line.trim());
  if (m == null) return null;
  final us = int.tryParse(m.group(1)!);
  if (us == null || us < 0) return null;
  final p = (us / totalDurationUs).clamp(0.0, 1.0).toDouble();
  return p > last ? p : null;
}
```

  - DI：`videoExportServiceProvider` 加 `processStarter: ref.watch(processRunnerProvider) as ProcessStarter`——**不这么写**；`processRunnerProvider` 类型是 `Provider<ProcessRunner>`。正确做法：`core/di/process_runner.dart` 加 `processStarterProvider = Provider<ProcessStarter>((ref) => const SystemProcessRunner(), name: ...)`（同实例 const，无状态共享问题）。
- [ ] **Step 4: 失败测试组二~五并逐组转绿**（每组先红后绿）：
  - 组二 进度：lines=[`out_time_ms=1500000`, `frame=42`(忽略), `out_time_ms=3000000`]，totalDurationMs=3000 → onProgress 收 [0.5, 1.0]（末尾成功强制 1.0 与解析值去重可接受，断言序列单调且终值 1.0）；totalDurationMs=null → 零回调；回退行 `out_time_ms=1000000` 在 1500000 之后 → 不回调。
  - 组三 取消：测试里 token.cancel() 于首个进度回调时触发 → 断言 fake.killed、输出文件被删、抛 CancelledError（`extra['reason']=='export_cancelled'`）、list 临时目录已清。
  - 组四 失败：exit=1 + stderr 尾部进 extra、半成品删除（现有用例迁移到流式后保持全绿）。
  - 组五 成功：返回相对路径不变；既有全部用例（保留名/非法名/空输入/input_not_found/ffmpeg_not_found）随构造参数迁移后全绿。
- [ ] **Step 5: 服务测试文件全绿**；`flutter.bat analyze lib test` 0 issue。
- [ ] **Step 6: Commit** `feat(export): concat 流式执行——进度解析+取消+半成品清理（EX-3 核心）`

### Task 3: ExportController 进度态 + 取消

**Files:**
- Modify: `lib/features/export/providers/export_controller.dart`
- Test: `test/features/export/providers/export_controller_test.dart`（扩展）

**Interfaces（Produces）:**
```dart
class ExportVideoBusy extends ExportVideoState {
  const ExportVideoBusy({this.progress});
  final double? progress;               // null=indeterminate
}
// ExportController 新增：
void cancelExport();                    // busy 外调用为 no-op
```

- [ ] **Step 1: 失败测试**：①fake service 的 onProgress 回调 0.5 → state 为 `ExportVideoBusy(progress:0.5)`；②节点 durationMs 齐全 → totalDurationMs=Σ、任一缺失 → null（fake service 捕参断言）；③cancelExport() → token.cancel 被传导（fake service 里 token.isCancelled）且 CancelledError 收敛为 `ExportVideoIdle`（不进 failure）；④busy 外 cancelExport no-op。
- [ ] **Step 2: 跑红**。
- [ ] **Step 3: 实现**：

```dart
ExportCancelToken? _token;
void cancelExport() => _token?.cancel();

// export() 内：
int? totalMs = 0;
for (final n in nodes) {
  if (n.canvasId == null || n.videoUrl == null) continue;
  final d = n.durationMs;
  if (d == null || d <= 0) { totalMs = null; break; }
  totalMs = totalMs! + d;
}
final token = ExportCancelToken();
_token = token;
state = const ExportVideoBusy();
try {
  final out = await service.concat(
    projectId: ..., inputRelativePaths: inputs, outputBaseName: ...,
    totalDurationMs: totalMs,
    onProgress: (p) { if (state is ExportVideoBusy) state = ExportVideoBusy(progress: p); },
    cancelToken: token,
  );
  state = ExportVideoSuccess(out);
} on CancelledError {
  state = const ExportVideoIdle();
} on InkError catch (e) { state = ExportVideoFailure(e); }
... // PathSecurityError 分支不动
finally { _token = null; link.close(); }
```
（注意 `on CancelledError` 必须排在 `on InkError` 之前。）
- [ ] **Step 4: 转绿**；controller 测试文件全绿。
- [ ] **Step 5: Commit** `feat(export): 控制器进度透传+取消收敛为 idle`

### Task 4: 对话框——determinate 进度+取消按钮+内嵌失败 banner+覆盖警示 + ARB

**Files:**
- Modify: `lib/features/export/widgets/export_video_dialog.dart`
- Modify: `lib/l10n/app_en.arb` / `lib/l10n/app_zh.arb`（+2 键）→ `flutter.bat gen-l10n` 重生成
- Test: `test/features/export/widgets/export_video_dialog_test.dart`（扩展）

**ARB 新键：**
```json
"exportVideoCancelExport": "Cancel export",
"exportVideoOverwriteWarning": "A file with this name already exists — exporting will overwrite it."
```
```json
"exportVideoCancelExport": "取消导出",
"exportVideoOverwriteWarning": "同名文件已存在，导出将覆盖它。"
```

- [ ] **Step 1: 失败测试**（fake controller/service 经 ProviderScope overrides，沿既有测试基建）：
  ①busy(progress:0.4) → InkProgressBar.value==0.4 且「取消导出」按钮可点；点击 → cancelExport 被调；
  ②failure 态 → 对话框内出现 InkErrorBanner（SnackBar 不再弹）且对话框未关闭、按钮回可用；
  ③输出名输入已存在文件名（temp 目录预置 `exports/dup.mp4`）→ 覆盖警示行出现；改名 → 消失；
  ④成功路径回归：pop+snackbar 不变。
- [ ] **Step 2: 跑红**。
- [ ] **Step 3: 实现**：
  - build 里 `final st = ref.watch(exportControllerProvider);`；busy 区：

```dart
if (st is ExportVideoBusy) ...<Widget>[
  const SizedBox(height: InkSpacing.md),
  InkProgressBar(value: st.progress),
  const SizedBox(height: InkSpacing.xs),
  Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: () =>
          ref.read(exportControllerProvider.notifier).cancelExport(),
      child: Text(l.exportVideoCancelExport),
    ),
  ),
],
if (st is ExportVideoFailure) ...<Widget>[
  const SizedBox(height: InkSpacing.md),
  InkErrorBanner(message: _failureText(st.error)),
],
```
  - `_onExport` 的 switch：删除 failure→SnackBar 分支（failure 由 build 内联渲染）；success 分支不动。
  - 覆盖警示：

```dart
bool get _wouldOverwrite {
  final name = _trimmedName;
  if (name.isEmpty || !isValidExportBaseName(name)) return false;
  try {
    return ref
        .read(fileResolverServiceProvider)
        .resolveInProject(
          projectId: widget.projectId,
          relativePath: 'exports/$name.mp4',
        )
        .existsSync();
  } on PathSecurityError {
    return false;
  }
}
```
    名字校验行下方 `if (_wouldOverwrite)` 出 caption 警示（颜色 colors.fg3 非 danger——是提示不是错误）。
  - import 补 `ink_error_banner.dart`。
- [ ] **Step 4: 转绿** + `flutter.bat gen-l10n` 后 `git status` 检查 generated/ 变更一并入库。
- [ ] **Step 5: Commit** `feat(export): 对话框进度/取消/内嵌失败横幅/同名覆盖警示（债144 收口）`

### Task 5: 真 ffmpeg 门控集成测

**Files:**
- Modify: `test/services/ffmpeg_concat_integration_test.dart`（扩展；`@Tags(['ffmpeg'])` + TEST_FFMPEG 门控沿现状）

- [ ] **Step 1: 加两用例**：①带 totalDurationMs 的 concat 收到 ≥1 次进度且终值 1.0；②启动后立即 cancel → 抛 CancelledError 且 exports 无残留文件。生成输入沿既有用例的 testsrc 短片手法。
- [ ] **Step 2: 本机验证**：`TEST_FFMPEG=1 flutter.bat test --tags ffmpeg`（本机有 ffmpeg 则真跑；无则确认 markTestSkipped 生效，CI 侧按现有矩阵）。
- [ ] **Step 3: Commit** `test(export): 真 ffmpeg 进度/取消集成测`

### Task 6: 文档同步 + 全量闸门

**Files:**
- Modify: `lib/features/export/README.md`（进度/取消/覆盖警示行为）
- Modify: `docs/BOARD.md`（债表 143/144 两行 ✅ + 近期落地表加行）
- Modify: `docs/MASTERPLAN.md`（§2 E4 行注 EX-3 ✅）
- Modify: `docs/ARCHITECTURE.md`（若 §其中有 ProcessRunner 节则补 ProcessStarter 一句；无则跳过）

- [ ] **Step 1: 文档改齐**（grep 宣称符号存在——PLAYBOOK §5.8）。
- [ ] **Step 2: 自查闸门四条**：analyze 0 issue → 全量 `flutter.bat test --exclude-tags golden`（白名单外零失败）→ ARB 齐平测过 → `git status` 干净。
- [ ] **Step 3: Commit** `docs: EX-3 收口同步（BOARD 债143/144、模块 README）`

### Task 7: 两路评审 + 修复（PLAYBOOK §1.4，不可省）

- [ ] **Step 1: 对抗评审 subagent**：输入=diff 概要+语义基准（取消收敛为 idle 非 failure；out_time_ms 微秒怪癖；进度单调；stderr 排干防背压；PopScope busy 不可关但可取消）+重点怀疑区（§5 模式 1/2/5/6：await 后 ref、双击、零时长、kill 竞态）。要求输出 findings{severity,file:line,反例}+verdict。
- [ ] **Step 2: 独立复跑 subagent**：analyze/全量计数/失败名单 vs 白名单/ARB/新测试文件单跑/git status，逐位核对。
- [ ] **Step 3: P1 全修、P2 低成本修**，回 Task 6 Step 2 重跑闸门。

### Task 8: PR

- [ ] **Step 1**: push 分支，`gh pr create`——标题 `feat(export): EX-3 导出进度+取消 + ProcessRunner 流式通道（债143/144 收口）`，body 含语义拍板要点、测试计数、评审摘要，尾注 🤖 生成行。
- [ ] **Step 2**: CI 五件套全绿确认（`gh run watch` 或轮询）；squash 合并按仓库惯例（合并动作留给维护者或 CI 权限允许则自动）。

## Self-Review 记录

- Spec 覆盖：EX-3 卡面五要点（流式接口/进度解析/取消/分母缺失 indeterminate/kill 风险仅 log）+ 债144 两件全部有任务映射 ✅
- 占位符扫描：无 TBD/伪代码步骤；全部给出真实代码 ✅
- 类型一致性：`ExportCancelToken.attach` / `ExportVideoBusy(progress:)` / `parseProgressLine(line, totalDurationUs:, last:)` 在 Task 2/3/4 间引用一致 ✅
- 修正一处：DI 不能把 `Provider<ProcessRunner>` 强转 ProcessStarter——新建 `processStarterProvider`（已写入 Task 2 Step 3）
