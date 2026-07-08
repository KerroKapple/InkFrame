// 测试用 PromptPreset 仓储 fake。
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/prompt_preset_repository.dart';

class FakePromptPresetRepo implements PromptPresetRepository {
  FakePromptPresetRepo([Map<String, Map<String, Object?>>? rows])
    : rows = rows ?? <String, Map<String, Object?>>{};

  final Map<String, Map<String, Object?>> rows;
  final List<String> softDeleted = <String>[];
  int createCalls = 0;

  /// 置 true 时 create 抛 LocalIOError（模拟落库失败路径）。
  bool failCreate = false;

  /// 仅对集合内 id 的 update 抛 LocalIOError（模拟并发下部分失败——LB-04 回滚交错）。
  final Set<String> failUpdateIds = <String>{};

  @override
  Future<String> create({
    required String projectId,
    String name = '',
    String prompt = '',
    String prefix = '',
    String suffix = '',
    String negative = '',
    int sortOrder = 0,
  }) async {
    if (failCreate) throw const LocalIOError();
    createCalls++;
    final id = 'preset-$createCalls';
    rows[id] = <String, Object?>{
      'id': id,
      'project_id': projectId,
      'name': name,
      'prompt': prompt,
      'prefix': prefix,
      'suffix': suffix,
      'negative': negative,
      'sort_order': sortOrder,
    };
    return id;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async => rows[id];

  @override
  Future<List<Map<String, Object?>>> listByProject(String projectId) async =>
      rows.values.where((r) => r['project_id'] == projectId).toList();

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    if (failUpdateIds.contains(id)) throw const LocalIOError();
    final row = rows[id];
    if (row == null) return 0;
    rows[id] = <String, Object?>{...row, ...patch};
    return 1;
  }

  @override
  Future<int> softDelete(String id) async {
    softDeleted.add(id);
    rows.remove(id);
    return 1;
  }

  @override
  Future<int> restore(String id) async => 1;

  @override
  Future<int> hardDelete(String id) async {
    rows.remove(id);
    return 1;
  }
}
