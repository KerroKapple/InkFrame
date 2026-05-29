import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/current_episode_view.dart';

void main() {
  test('默认视图为 canvas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(currentEpisodeViewProvider), EpisodeView.canvas);
  });

  test('EpisodeView 顺序与 mockup EPISODE_VIEWS 一致', () {
    expect(EpisodeView.values, <EpisodeView>[
      EpisodeView.canvas,
      EpisodeView.storyboard,
      EpisodeView.script,
      EpisodeView.generation,
      EpisodeView.queue,
    ]);
  });

  test('可切换视图', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(currentEpisodeViewProvider.notifier).state =
        EpisodeView.storyboard;
    expect(container.read(currentEpisodeViewProvider), EpisodeView.storyboard);
  });
}
