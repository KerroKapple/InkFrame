// restoreLastSessionProvider：启动恢复上次画布的全场景单测。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/canvas_repository.dart';
import 'package:inkframe/core/interfaces/project_repository.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/gallery/providers/current_gallery_project.dart';
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
      projectRow: <String, Object?>{'id': 'p1'},
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

  test('用户已手动打开画布 → 不抢占', () async {
    final (:c, :prefs) = build(
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p1'},
      projectRow: <String, Object?>{'id': 'p1'},
    );
    c.read(currentCanvasIdProvider.notifier).state = 'cv-manual';
    await c.read(restoreLastSessionProvider.future);
    expect(c.read(currentCanvasIdProvider), 'cv-manual');
  });

  test('债145：用户已进 Settings → 放弃恢复（不硬拉回画布）', () async {
    final (:c, prefs: _) = build(
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p1'},
      projectRow: <String, Object?>{'id': 'p1'},
    );
    c.read(currentScreenProvider.notifier).state = AppScreen.settings;

    await c.read(restoreLastSessionProvider.future);

    expect(c.read(currentCanvasIdProvider), isNull);
    expect(c.read(currentScreenProvider), AppScreen.settings,
        reason: '用户所在页不被打断');
  });

  test('债145：用户已进 Gallery → 放弃恢复', () async {
    final (:c, prefs: _) = build(
      canvasRow: <String, Object?>{'id': 'cv1', 'project_id': 'p1'},
      projectRow: <String, Object?>{'id': 'p1'},
    );
    c.read(currentGalleryProjectProvider.notifier).state =
        (id: 'p9', name: 'Nine');

    await c.read(restoreLastSessionProvider.future);

    expect(c.read(currentCanvasIdProvider), isNull);
  });

  test('存储抛 InkError → 静默留在首页，记录保留（下次再试）', () async {
    final (:c, :prefs) = build(canvasError: const LocalIOError());
    await c.read(restoreLastSessionProvider.future);
    expect(c.read(currentCanvasIdProvider), isNull);
    expect(prefs.current.lastCanvasId, 'cv1'); // 未被清
  });
}
