// PromptPresetRepository 契约：prompt_presets 表（项目级提示词预设库）。
abstract class PromptPresetRepository {
  Future<String> create({
    required String projectId,
    String name = '',
    String prompt = '',
    String prefix = '',
    String suffix = '',
    String negative = '',
    int sortOrder = 0,
  });

  Future<Map<String, Object?>?> findById(String id);

  Future<List<Map<String, Object?>>> listByProject(String projectId);

  Future<int> update(String id, Map<String, Object?> patch);
  Future<int> softDelete(String id);
  Future<int> restore(String id);
  Future<int> hardDelete(String id);
}
