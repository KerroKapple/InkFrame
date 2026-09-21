// restoreLastSessionProvider：启动恢复上次画布的全场景单测。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/studio/providers/restore_last_session.dart';
import 'package:inkframe/services/file_preferences_service.dart';

class _FakeCanvasRepo implements CanvasRepository {
  _FakeCanvasRepo({this.row, this.error});

  final Map<String, Object?>? row;
  final InkError? error;

  @override
  Future<Map<String, Object?>?> findById(String id) async {
    final e = error;
    if (e != null) throw e;
    return row;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeProjectRepo implements ProjectRepository {
  _FakeProjectRepo({this.row});

  final Map<String, Object?>? row;

  @override
  Future<Map<String, Object?>?> findById(String id) async => row;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  const savedPrefs = AppPreferences(lastCanvasId: 'cv1', lastProjectId: 'p1');

  ({
    ProviderContainer c,
    InMemoryPreferencesService prefs,
  }) build({
    AppPreferences seed = savedPrefs,
    Map<String, Object?>? canvasRow,
    Map<String, Object?>? projectRow,
    InkError? canvasError,
  }) {
    final prefs = InMemoryPreferencesService(seed);
    final c = ProviderContainer(overrides: [
      preferencesServiceProvider.overrideWithValue(prefs),
      canvasRepositoryProvider.overrideWith(
        (ref) async => _FakeCanvasRepo(row: canvasRow, error: canvasError),
      ),
      projectRepositoryProvider.overrideWith(
        (ref) async => _FakeProjectRepo(row: projectRow),
      ),
    ]);
    addTearDown(c.dispose);
    return (c: c, prefs: prefs);
  }

  test('画布/项目均有效 → 置 currentCanvasId', () async {
    final (:c, :prefs) = build(
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p1'},
      projectRow: <String, Object?>{'id': 'p1', 'name': 'Project One'},
    );
    await c.read(restoreLastSessionProvider.future);
    expect(c.read(currentCanvasIdProvider), 'cv1');
    expect(prefs.current.lastCanvasId, 'cv1'); // 记录保留
  });

  test('偏好里没有记录 → 直接返回，不触存储', () async {
    final (:c, :prefs) = build(seed: const AppPreferences());
    await c.read(restoreLastSessionProvider.future);
    expect(c.read(currentCanvasIdProvider), isNull);
  });

  test('画布已软删（findById null）→ 清记录、留在首页', () async {
    final (:c, :prefs) = build(
      canvasRow: null,
      projectRow: <String, Object?>{'id': 'p1'},
    );
    await c.read(restoreLastSessionProvider.future);
    expect(c.read(currentCanvasIdProvider), isNull);
    expect(prefs.current.lastCanvasId, isNull);
    expect(prefs.current.lastProjectId, isNull);
  });

  test('项目已软删 → 清记录、留在首页（画布行还在也不恢复）', () async {
    final (:c, :prefs) = build(
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p1'},
      projectRow: null,
    );
    await c.read(restoreLastSessionProvider.future);
    expect(c.read(currentCanvasIdProvider), isNull);
    expect(prefs.current.lastCanvasId, isNull);
  });

  test('画布归属项目与记录不符 → 判无效并清记录', () async {
    final (:c, :prefs) = build(
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p-other'},
      projectRow: <String, Object?>{'id': 'p1'},
    );
    await c.read(restoreLastSessionProvider.future);
    expect(c.read(currentCanvasIdProvider), isNull);
    expect(prefs.current.lastCanvasId, isNull);
  });

  // ===== 守卫判据 = ShellState.isPristine =====
  //
  // T11 语义重写：这三例原来的前提是「seed currentScreen=settings」/
  // 「gallery 目标 = 用户已导航」，靠的是 T6 就已删掉的两个路由 provider；
  // T6 只让它们能编译，语义留给这里。新判据是 isPristine，它是三项合取：
  //   canvasId == null && overlay == null && tab == ShellTab.studio
  // 三例各打掉其中一项，逐项钉死——任何一项从判据里漏掉都会有一例转红。

  test('isPristine 项一（canvasId）：用户已手动打开画布 → 不抢占', () async {
    final (:c, :prefs) = build(
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p1'},
      projectRow: <String, Object?>{'id': 'p1', 'name': 'Project One'},
    );
    // 打开画布后再回 Studio 标签：canvasId 留着（保活语义），tab/overlay
    // 都回到初值——于是本例与 isPristine 的差别【只有】canvasId 这一项，
    // 单独钉住它（openCanvas 会连带把 tab 翻成 canvas，那样就分不清
    // 红是 canvasId 项还是 tab 项在起作用）。
    c.read(shellControllerProvider.notifier).openCanvas('cv-manual');
    c.read(shellControllerProvider.notifier).goTab(ShellTab.studio);

    await c.read(restoreLastSessionProvider.future);

    expect(c.read(currentCanvasIdProvider), 'cv-manual');
    expect(prefs.current.lastCanvasId, 'cv1', reason: '放弃恢复 ≠ 清记录');
  });

  test('isPristine 项二（overlay）：用户已开设置浮层 → 放弃恢复', () async {
    final (:c, :prefs) = build(
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p1'},
      projectRow: <String, Object?>{'id': 'p1', 'name': 'Project One'},
    );
    c.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.settings);

    await c.read(restoreLastSessionProvider.future);

    // 整个外壳态原封不动：tab 没被换、浮层没被顶掉、canvasId 没被塞。
    expect(
      c.read(shellControllerProvider),
      const ShellState(tab: ShellTab.studio, overlay: ShellOverlay.settings),
      reason: '用户所在页不被打断',
    );
    expect(prefs.current.lastCanvasId, 'cv1', reason: '放弃恢复 ≠ 清记录');
  });

  test('isPristine 项三（tab）：用户已切到其他标签 → 放弃恢复', () async {
    // brief 声称「tab 默认 studio，所以切到任何标签 isPristine 自然为假」；
    // 这一例就是那条纸面推理的实测——canvasId 与 overlay 都还是初值，
    // 唯一的差别是 tab。
    final (:c, :prefs) = build(
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p1'},
      projectRow: <String, Object?>{'id': 'p1', 'name': 'Project One'},
    );
    c.read(shellControllerProvider.notifier).goTab(ShellTab.gallery);

    await c.read(restoreLastSessionProvider.future);

    expect(c.read(shellControllerProvider).tab, ShellTab.gallery);
    expect(c.read(currentCanvasIdProvider), isNull);
    expect(prefs.current.lastCanvasId, 'cv1', reason: '放弃恢复 ≠ 清记录');
  });

  test('开关 false 时不恢复，且不清记录', () async {
    // 关掉开关不等于放弃记录——用户可能只是这次不想回去，
    // 下次把开关打开还应当回到同一张画布。
    final (:c, :prefs) = build(
      seed: const AppPreferences(
        lastCanvasId: 'cv1',
        lastProjectId: 'p1',
        shellKeepLastCanvas: false,
      ),
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p1'},
      projectRow: <String, Object?>{'id': 'p1', 'name': 'Project One'},
    );

    await c.read(restoreLastSessionProvider.future);

    expect(c.read(shellControllerProvider).isPristine, isTrue, reason: '没恢复');
    expect(prefs.current.lastCanvasId, 'cv1', reason: '记录仍在');
    expect(prefs.current.lastProjectId, 'p1', reason: '记录仍在');
  });

  test('开关 false + 记录已失效（画布被软删）→ 仍不清记录', () async {
    // R80：这一例钉的是开关守卫的【位置】，不只是它的存在性。
    // 上一例喂的是【有效】记录——那一格无论守卫放在库查询之前还是放在
    // `if (!valid)` 之后，行为都一样，对位置零鉴别力。
    // 只有「开关关 + 记录恰好失效」这一格能把两个位置分开：守卫前置 →
    // 压根不查库，记录留着；守卫后置 → 先判无效、走 clearLastCanvas，
    // 记录被静默清掉，用户重新打开开关也回不去了。
    final (:c, :prefs) = build(
      seed: const AppPreferences(
        lastCanvasId: 'cv1',
        lastProjectId: 'p1',
        shellKeepLastCanvas: false,
      ),
      canvasRow: null,
      projectRow: null,
    );

    await c.read(restoreLastSessionProvider.future);

    expect(prefs.current.lastCanvasId, 'cv1');
    expect(prefs.current.lastProjectId, 'p1');
  });

  test('存储抛 InkError → 静默留在首页，记录保留（下次再试）', () async {
    final (:c, :prefs) = build(canvasError: const LocalIOError());
    await c.read(restoreLastSessionProvider.future);
    expect(c.read(currentCanvasIdProvider), isNull);
    expect(prefs.current.lastCanvasId, 'cv1'); // 未被清
  });
}
