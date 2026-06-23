import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/generation/services/prompt_assembler.dart';

void main() {
  test('joins all non-empty segments with ", "', () {
    final r = assemblePrompt(
      baseStylePrefix: 'cinematic',
      laneStylePrompt: 'warm light',
      associatedTexts: ['a girl', 'red coat'],
      userPrompt: 'walking',
      baseStyleSuffix: '8k',
    );
    expect(r, 'cinematic, warm light, a girl, red coat, walking, 8k');
  });
  test('skips empty segments, no dangling comma', () {
    expect(assemblePrompt(userPrompt: 'solo'), 'solo');
    expect(assemblePrompt(baseStylePrefix: 'x', userPrompt: 'y'), 'x, y');
  });
  test('does not add comma after a segment ending in punctuation', () {
    expect(assemblePrompt(baseStylePrefix: 'a scene.', userPrompt: 'night'), 'a scene. night');
  });
  test('ignoreLaneStyle drops the lane segment', () {
    final r = assemblePrompt(laneStylePrompt: 'warm', userPrompt: 'cat', ignoreLaneStyle: true);
    expect(r, 'cat');
  });
  test('associated texts keep given order', () {
    expect(assemblePrompt(associatedTexts: ['1', '2', '3'], userPrompt: 'p'), '1, 2, 3, p');
  });
}
