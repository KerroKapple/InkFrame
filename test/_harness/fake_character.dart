// 测试用 Character 仓储 / 资产服务 fake。
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/character_asset_service.dart';
import 'package:inkframe/core/interfaces/character_repository.dart';

class FakeCharacterRepo implements CharacterRepository {
  FakeCharacterRepo([Map<String, Map<String, Object?>>? rows])
    : rows = rows ?? <String, Map<String, Object?>>{};

  final Map<String, Map<String, Object?>> rows;
  final List<String> softDeleted = <String>[];
  int createCalls = 0;

  /// 置 true 时 update 抛 LocalIOError（模拟回滚/失败路径）。
  bool failUpdate = false;

  /// 仅对集合内 id 的 update 抛 LocalIOError（模拟并发下部分失败——LB-04 回滚交错）。
  final Set<String> failUpdateIds = <String>{};

  /// 置 true 时 create 抛 LocalIOError（模拟落库失败路径）。
  bool failCreate = false;

  /// 置 true 时 hardDelete 抛 LocalIOError（模拟补偿失败路径）。
  bool failHardDelete = false;

  @override
  Future<String> create({
    required String projectId,
    String name = '',
    List<String> referenceImagePaths = const <String>[],
    String description = '',
    int sortOrder = 0,
  }) async {
    if (failCreate) throw const LocalIOError();
    createCalls++;
    final id = 'char-$createCalls';
    rows[id] = <String, Object?>{
      'id': id,
      'project_id': projectId,
      'name': name,
      'reference_image_paths': referenceImagePaths,
      'description': description,
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
    if (failUpdate || failUpdateIds.contains(id)) throw const LocalIOError();
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
    if (failHardDelete) throw const LocalIOError();
    rows.remove(id);
    return 1;
  }
}

class FakeCharacterAssetService implements CharacterAssetService {
  FakeCharacterAssetService({this.existing});

  /// 若给定，resolveExisting 只回其中在此集合里的绝对路径（模拟磁盘存在性）。
  final Set<String>? existing;
  final List<String> imported = <String>[];
  final List<String> deleted = <String>[];

  @override
  Future<String> importImage({
    required String projectId,
    required String sourceAbsolutePath,
    required String fileBaseName,
  }) async {
    final rel = 'characters/$fileBaseName.png';
    imported.add(rel);
    return rel;
  }

  @override
  String absolutePathOf({
    required String projectId,
    required String relativePath,
  }) => '/abs/$projectId/$relativePath';

  @override
  Future<List<String>> resolveExisting({
    required String projectId,
    required List<String> relativePaths,
  }) async {
    final out = <String>[];
    for (final rel in relativePaths) {
      final abs = absolutePathOf(projectId: projectId, relativePath: rel);
      if (existing == null || existing!.contains(abs)) out.add(abs);
    }
    return out;
  }

  @override
  Future<void> delete({
    required String projectId,
    required String relativePath,
  }) async {
    deleted.add(relativePath);
  }
}
