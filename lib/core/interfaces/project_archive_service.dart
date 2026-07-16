// ProjectArchiveService 契约：整项目导出为单 zip（LB-11）。
//
// zip 布局：manifest.json + data.json + files/（= projects/{id} 目录全量镜像，
// 路径一律 '/' 分隔）。写盘纪律：先 <target>.partial 再原子 rename；
// 任何失败清 partial 并抛 LocalIOError。
abstract class ProjectArchiveService {
  Future<void> exportProject({
    required String projectId,
    required String targetPath,
  });
}
