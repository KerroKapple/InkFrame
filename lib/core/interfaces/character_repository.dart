// CharacterRepository 契约：characters 表（项目级角色一致性）。
abstract class CharacterRepository {
  Future<String> create({
    required String projectId,
    String name = '',
    List<String> referenceImagePaths = const <String>[],
    String description = '',
    int sortOrder = 0,
  });

  Future<Map<String, Object?>?> findById(String id);

  Future<List<Map<String, Object?>>> listByProject(String projectId);

  Future<int> update(String id, Map<String, Object?> patch);
  Future<int> softDelete(String id);
  Future<int> restore(String id);
  Future<int> hardDelete(String id);
}
