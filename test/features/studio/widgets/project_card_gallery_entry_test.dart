// 项目卡菜单「Gallery」入口：点击后设置 currentGalleryProjectProvider（id+name）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/features/gallery/providers/current_gallery_project.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/providers/workspace_projects_provider.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('项目卡菜单 Gallery → 设置画廊浏览目标', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              createdAt: DateTime.utc(2026, 5, 1),
              canvases: const <CanvasRef>[],
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StudioHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(currentGalleryProjectProvider), isNull);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(
      container.read(currentGalleryProjectProvider),
      (id: 'p1', name: 'Alpha'),
    );
  });

  testWidgets('项目卡菜单 Built-in samples → 切到内置示例页', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (_) async => <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Alpha',
              createdAt: DateTime.utc(2026, 5, 1),
              canvases: const <CanvasRef>[],
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StudioHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(currentScreenProvider), AppScreen.studio);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Built-in samples'));
    await tester.pumpAndSettle();

    expect(container.read(currentScreenProvider), AppScreen.showcase);
  });
}
