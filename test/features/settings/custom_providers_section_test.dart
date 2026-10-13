// CustomProvidersSection widget 测试（GAP-1）：列表/添加/编辑/删除/内联校验/
// 损坏文件错误呈现/重启提示。fake CustomProviderStore,零磁盘。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/custom_providers.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/custom_provider_store.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';
import 'package:inkframe/features/settings/widgets/custom_providers_section.dart';

import '../../_harness/test_app.dart';

CustomProviderConfig _cfg({
  String id = 'my-relay',
  String displayName = 'My Relay',
}) =>
    CustomProviderConfig(
      id: id,
      displayName: displayName,
      template: 'openai-image',
      baseUrl: 'https://relay.example.com/v1',
      modelId: 'flux-pro',
    );

class _FakeStore implements CustomProviderStore {
  _FakeStore([List<CustomProviderConfig>? seed])
      : entries = [...?seed];
  final List<CustomProviderConfig> entries;
  bool broken = false;

  @override
  Future<List<CustomProviderConfig>> list() async {
    if (broken) throw const LocalIOError(extra: {'reason': 'corrupted'});
    return List.unmodifiable(entries);
  }

  @override
  Future<void> upsert(CustomProviderConfig config) async {
    if (broken) throw const LocalIOError(extra: {'reason': 'corrupted'});
    final i = entries.indexWhere((e) => e.id == config.id);
    if (i >= 0) {
      entries[i] = config;
    } else {
      entries.add(config);
    }
  }

  @override
  Future<void> remove(String id) async {
    if (broken) throw const LocalIOError(extra: {'reason': 'corrupted'});
    entries.removeWhere((e) => e.id == id);
  }
}

Future<void> _pump(WidgetTester tester, _FakeStore store) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: SingleChildScrollView(child: CustomProvidersSection())),
    surfaceSize: const Size(900, 900),
    overrides: [
      customProviderStoreProvider.overrideWithValue(store),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('空态 → empty 文案;有条目 → 行渲染 displayName + providerId',
      (tester) async {
    await _pump(tester, _FakeStore());
    expect(find.text('No custom providers yet'), findsOneWidget);

    await _pump(tester, _FakeStore([_cfg()]));
    expect(find.text('My Relay'), findsOneWidget);
    expect(find.textContaining('custom:my-relay'), findsOneWidget);
  });

  testWidgets('添加流:合法输入 → store.upsert + 列表刷新 + 重启提示', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);

    await tester.tap(find.text('Add custom provider…'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'new-relay');
    await tester.enterText(fields.at(1), 'New Relay');
    await tester.enterText(fields.at(2), 'https://api.example.com/v1/');
    await tester.enterText(fields.at(3), 'sdxl');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.entries.single.id, 'new-relay');
    // 尾斜杠已规范化
    expect(store.entries.single.baseUrl, 'https://api.example.com/v1');
    expect(find.text('New Relay'), findsOneWidget);
    expect(
      find.text('Changes saved — restart InkFrame to apply'),
      findsOneWidget,
    );
  });

  testWidgets('内联校验:重复 id 与带 query 的 base_url 报错不提交', (tester) async {
    final store = _FakeStore([_cfg()]);
    await _pump(tester, store);

    await tester.tap(find.text('Add custom provider…'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'my-relay'); // 撞现存
    await tester.enterText(fields.at(1), 'Dup');
    await tester.enterText(fields.at(2), 'https://x.com/v1?key=1');
    await tester.enterText(fields.at(3), 'm');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('This ID is already in use'), findsOneWidget);
    expect(
      find.text('Absolute http(s) URL without query, fragment or credentials'),
      findsOneWidget,
    );
    // 未提交:对话框仍开,store 未变
    expect(store.entries, hasLength(1));
    expect(find.text('Add custom provider'), findsOneWidget);
  });

  testWidgets('编辑流:id 字段锁定,保存走 upsert 原 id', (tester) async {
    final store = _FakeStore([_cfg()]);
    await _pump(tester, store);

    await tester.tap(find.byTooltip('Edit custom provider'));
    await tester.pumpAndSettle();

    final idField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(idField.enabled, isFalse);

    await tester.enterText(find.byType(TextField).at(1), 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.entries.single.id, 'my-relay');
    expect(store.entries.single.displayName, 'Renamed');
  });

  testWidgets('删除流:确认对话框 → remove;取消不动', (tester) async {
    final store = _FakeStore([_cfg()]);
    await _pump(tester, store);

    await tester.tap(find.byTooltip('Delete provider?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.entries, hasLength(1));

    await tester.tap(find.byTooltip('Delete provider?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('My Relay'), findsWidgets);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.entries, isEmpty);
  });

  testWidgets('损坏文件:列表 error 呈现不崩;读拒绝 → 读失败 snackbar', (tester) async {
    final store = _FakeStore()..broken = true;
    await _pump(tester, store);

    // 列表 error 态（LocalIOError → l10n 文案）
    expect(
      find.text('Local disk I/O error. Check space and permissions.'),
      findsOneWidget,
    );

    // 添加入口仍可点；此处失败的是 `list()`——**读**，不是写。
    //
    // 这条断言原来写的是 `Couldn't save`，把错位的文案钉死了（GAP-1 评审 P3②）：
    // 用户只是点开「添加」，什么都还没填、更没保存，弹出来却是「保存失败」，
    // 第一反应是「我刚填的被弄丢了」。文案错位比没有文案更坏。
    await tester.tap(find.text('Add custom provider…'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("Couldn't read custom_providers.json"),
      findsOneWidget,
    );
    expect(
      find.textContaining("Couldn't save"),
      findsNothing,
      reason: '读失败不该说成保存失败',
    );
  });

  // 反向：真的写失败时，仍然是「保存失败」那一句。
  testWidgets('读得到但写拒绝 → 保存失败 snackbar（不是读失败）', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);

    await tester.tap(find.text('Add custom provider…'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).at(0), 'relay-2');
    await tester.enterText(
        find.byType(TextField).at(1), 'Relay 2');
    await tester.enterText(
        find.byType(TextField).at(2), 'https://relay2.example.com/v1');
    await tester.enterText(find.byType(TextField).at(3), 'flux-pro');
    // 表单读过一次之后才让 store 坏掉——这样失败的一定是 upsert。
    store.broken = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't save"), findsOneWidget);
    expect(
      find.textContaining("Couldn't read custom_providers.json"),
      findsNothing,
    );
  });
}
