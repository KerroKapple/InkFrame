// FileResolverService 抽象：唯一拥有绝对路径的服务（PRD §12.6 相对路径契约）。
//
// 职责：在 DB 相对路径与磁盘绝对路径之间双向转换，并守住 canvas 根目录边界。
//
// 约束：
//   - DB 只存 canvas 相对路径（形如 images/{uuid}.png）
//   - Widget / ViewModel 禁止直接 new File(...)；必须经本服务
//   - 所有绝对路径回写必须校验在 canvas 根目录之内，拒绝 '..' 穿越、绝对路径、空串、控制字符
//   - 同盘 rename / 跨盘 copy+verify+rm 由 toRelative 的调用方在迁移流程里处理，本服务不涉
//
// 错误：路径非法（穿越 / 绝对 / 空 / 控制字符 / 越界）→ 抛 [PathSecurityError]。
//
// 根目录布局（与 AppPaths.projects 一致）：
//   <root>/projects/{project-id}/canvases/{canvas-id}/（root 见 AppPaths）

import 'dart:io';

abstract class FileResolverService {
  /// 相对路径 → 绝对 File。相对路径非法时抛 [PathSecurityError]。
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  });

  /// 项目根相对路径 → 绝对 File（守 `projects/{project-id}/` 边界）。
  /// 跨画布/项目级产物（如 `exports/<name>.mp4`、`canvases/<c>/videos/<f>`）
  /// 走此入口；相对路径非法时抛 [PathSecurityError]。
  File resolveInProject({
    required String projectId,
    required String relativePath,
  });

  /// 绝对路径 → 相对路径；源路径不在指定 canvas 根目录内时抛 [PathSecurityError]。
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  });

  /// 返回 canvas 根目录绝对路径（不保证存在）。
  Directory canvasRoot({required String projectId, required String canvasId});
}

/// 非法路径（穿越 / 绝对 / 空 / 控制字符等）。FileResolverService 契约的一部分。
class PathSecurityError extends ArgumentError {
  PathSecurityError(super.message);
}
