// NodeCard 拖拽视觉态：onPanStart → onPanEnd 之间 _dragging=true，
// 表现为 AnimatedScale.scale 由 1.0 抬升到 1.02，且阴影切到 InkShadow.elevated。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:inkframe/theme/app_theme.dart';

class _FakeResolver implements FileResolverService {
  _FakeResolver(this.dir);
  final Directory dir;

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      dir;

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('${dir.path}/$relativePath');

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      source.path;
}

Widget _host(Widget child) => ProviderScope(
      overrides: <Override>[
        fileResolverServiceProvider
            .overrideWithValue(_FakeResolver(Directory.systemTemp)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('pan 开始 → AnimatedScale 切到 1.02；pan 结束 → 回到 1.0',
      (tester) async {
    Offset accumulated = Offset.zero;
    const n = CanvasNode(
      id: 'n1',
      label: 'Drag me',
      type: CanvasNodeType.image,
    );
    await tester.pumpWidget(
      _host(NodeCard(
        node: n,
        selected: false,
        onTap: () {},
        onPanUpdate: (d) => accumulated += d,
      )),
    );
    await tester.pumpAndSettle();

    AnimatedScale scaleWidget() => tester
        .widget<AnimatedScale>(find.byType(AnimatedScale).first);
    expect(scaleWidget().scale, 1.0);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Drag me')));
    await gesture.moveBy(const Offset(30, 40));
    await tester.pump();
    expect(scaleWidget().scale, 1.02);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleWidget().scale, 1.0);
    // 注：onPanUpdate 的累计值不在本测试范围（驱动器对 pan 事件分发的细节会
    // 影响 accumulated 是否落到 onPanUpdate），重点是 _dragging 视觉态切换。
  });
}
