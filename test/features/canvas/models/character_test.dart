import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/character.dart';

void main() {
  group('Character.fromRow', () {
    test('JSONB 已解码 List → referenceImagePaths', () {
      final c = Character.fromRow(<String, Object?>{
        'id': 'c1',
        'project_id': 'p1',
        'name': 'Hero',
        'description': 'a hero',
        'reference_image_paths': <String>['characters/a.png', 'characters/b.png'],
        'sort_order': 2,
      });
      expect(c.id, 'c1');
      expect(c.projectId, 'p1');
      expect(c.name, 'Hero');
      expect(c.description, 'a hero');
      expect(c.referenceImagePaths, ['characters/a.png', 'characters/b.png']);
      expect(c.sortOrder, 2);
    });

    test('JSONB 文本(String) 也能解码', () {
      final c = Character.fromRow(<String, Object?>{
        'id': 'c1',
        'project_id': 'p1',
        'reference_image_paths': '["characters/a.png"]',
      });
      expect(c.referenceImagePaths, ['characters/a.png']);
    });

    test('null/缺失 → 空列表 + 默认值', () {
      final c = Character.fromRow(<String, Object?>{'id': 'c1', 'project_id': 'p1'});
      expect(c.referenceImagePaths, isEmpty);
      expect(c.name, '');
      expect(c.description, '');
      expect(c.sortOrder, 0);
    });
  });

  test('copyWith + 值等价（列表按序）', () {
    const a = Character(
      id: 'c1',
      projectId: 'p1',
      name: 'A',
      referenceImagePaths: ['x'],
    );
    expect(a == a.copyWith(), isTrue);
    expect(a.copyWith(name: 'B').name, 'B');
    expect(a.copyWith(name: 'B').id, 'c1');

    const same = Character(
      id: 'c1',
      projectId: 'p1',
      name: 'A',
      referenceImagePaths: ['x'],
    );
    expect(a == same, isTrue);
    expect(a.hashCode, same.hashCode);

    const reordered = Character(
      id: 'c1',
      projectId: 'p1',
      name: 'A',
      referenceImagePaths: ['y', 'x'],
    );
    expect(a == reordered, isFalse);
  });
}
