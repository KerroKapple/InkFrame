import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/prompt_preset.dart';

void main() {
  test('fromRow 全字段', () {
    final p = PromptPreset.fromRow(<String, Object?>{
      'id': 'p1',
      'project_id': 'proj',
      'name': 'Cinematic',
      'prompt': 'a',
      'prefix': 'b',
      'suffix': 'c',
      'negative': 'd',
      'sort_order': 3,
    });
    expect(p.id, 'p1');
    expect(p.projectId, 'proj');
    expect(p.name, 'Cinematic');
    expect(p.prompt, 'a');
    expect(p.prefix, 'b');
    expect(p.suffix, 'c');
    expect(p.negative, 'd');
    expect(p.sortOrder, 3);
  });

  test('fromRow 缺省', () {
    final p = PromptPreset.fromRow(<String, Object?>{
      'id': 'p1',
      'project_id': 'proj',
    });
    expect(p.name, '');
    expect(p.prompt, '');
    expect(p.negative, '');
    expect(p.sortOrder, 0);
  });

  test('copyWith + == + hashCode', () {
    const a = PromptPreset(id: 'p1', projectId: 'proj', name: 'A', prompt: 'x');
    expect(a.copyWith(name: 'B').name, 'B');
    expect(a.copyWith(name: 'B').prompt, 'x');
    expect(a == a.copyWith(), isTrue);
    const same = PromptPreset(
      id: 'p1',
      projectId: 'proj',
      name: 'A',
      prompt: 'x',
    );
    expect(a, same);
    expect(a.hashCode, same.hashCode);
    const diff = PromptPreset(
      id: 'p1',
      projectId: 'proj',
      name: 'A',
      prompt: 'y',
    );
    expect(a == diff, isFalse);
  });
}
