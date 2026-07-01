import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/prompt_presets_controller.dart';

import '../../../_harness/fake_prompt_preset.dart';

void main() {
  late FakePromptPresetRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakePromptPresetRepo();
    container = ProviderContainer(
      overrides: <Override>[
        promptPresetRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<PromptPresetsController> boot(String projectId) async {
    final sub = container.listen(
      promptPresetsControllerProvider(projectId),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await container.read(promptPresetsControllerProvider(projectId).future);
    return container.read(promptPresetsControllerProvider(projectId).notifier);
  }

  test('build 列出项目预设', () async {
    repo.rows['p1'] = <String, Object?>{
      'id': 'p1',
      'project_id': 'proj',
      'name': 'Cinematic',
      'prompt': 'cinematic lighting',
      'negative': 'blurry',
    };
    await boot('proj');
    final list = container
        .read(promptPresetsControllerProvider('proj'))
        .valueOrNull!;
    expect(list, hasLength(1));
    expect(list.single.name, 'Cinematic');
    expect(list.single.prompt, 'cinematic lighting');
    expect(list.single.negative, 'blurry');
  });

  test('create + reload', () async {
    final notifier = await boot('proj');
    final id = await notifier.create(
      name: 'Anime',
      prompt: 'anime style',
      negative: 'lowres',
    );
    final row = repo.rows[id]!;
    expect(row['name'], 'Anime');
    expect(row['prompt'], 'anime style');
    final list = container
        .read(promptPresetsControllerProvider('proj'))
        .valueOrNull!;
    expect(list.any((p) => p.id == id), isTrue);
  });

  test('rename + delete', () async {
    repo.rows['p1'] = <String, Object?>{
      'id': 'p1',
      'project_id': 'proj',
      'name': 'Old',
    };
    final notifier = await boot('proj');
    await notifier.rename('p1', 'New');
    expect(repo.rows['p1']!['name'], 'New');
    await notifier.delete('p1');
    expect(repo.softDeleted, contains('p1'));
    final list = container
        .read(promptPresetsControllerProvider('proj'))
        .valueOrNull!;
    expect(list, isEmpty);
  });
}
