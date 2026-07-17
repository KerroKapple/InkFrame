// ProjectImportWriter：导入写侧契约（LB-12）。
//
// 为什么不走常规仓储 create()：导入要**保真**（显式 id / created_at / deleted_at
// 原样落库），仓储 create 不收这些；本契约由专用 PG 实现以 raw INSERT + 单事务
// 落地（与 LB-11 的专用读侧 ProjectArchiveReader 对偶）。
import '../models/import_plan_data.dart';

abstract class ProjectImportWriter {
  /// 单事务写入整个 plan（FK 序内部保证）；任一行失败整体回滚（零残留）。
  Future<void> writeAll(ImportPlanData plan);
}
