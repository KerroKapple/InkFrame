// Workspace v2 静态复刻：1600×1000 设计尺寸下整页可布局、无溢出、稿上原文都在。
// 像素级对齐由 lib/replica_main.dart 自截图 + scripts/replica_diff.ps1 在 Windows 实机验收，
// 这里只守「结构不塌」。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/workspace/models/workspace_fixture.dart';
import 'package:inkframe/features/workspace/workspace_v2_screen.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('1600×1000 下整页布局无溢出，稿上关键原文全部渲染', (tester) async {
    await tester.binding.setSurfaceSize(WorkspaceV2Screen.designSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        home: const WorkspaceV2Screen(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(WorkspaceV2Screen)), WorkspaceV2Screen.designSize);

    for (final String text in <String>[
      WorkspaceFixture.breadcrumb.last,
      WorkspaceFixture.exportVideo,
      WorkspaceFixture.promptTarget,
      WorkspaceFixture.inspectorNodeMeta,
      WorkspaceFixture.jobs.first.model,
      WorkspaceFixture.version,
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    // 六个节点各渲染一次名字（左栏节点列表另有同名行，故 ≥1 而非 ==1）。
    for (final WsNode n in WorkspaceFixture.nodes) {
      expect(find.text(n.name), findsWidgets, reason: n.name);
    }
  });
}
