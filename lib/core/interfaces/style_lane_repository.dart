// StyleLaneRepository 契约：style_lanes 表。
import '../constants/lane_defaults.dart';

abstract class StyleLaneRepository {
  Future<String> create({
    required String canvasId,
    String label = '',
    String stylePrompt = '',
    int sortOrder = 0,
    String? tintColor,
    double size = kDefaultLaneSize,
  });

  Future<Map<String, Object?>?> findById(String id);

  Future<List<Map<String, Object?>>> listByCanvas(String canvasId);

  Future<int> update(String id, Map<String, Object?> patch);
  Future<int> softDelete(String id);
  Future<int> restore(String id);
  Future<int> hardDelete(String id);
}
