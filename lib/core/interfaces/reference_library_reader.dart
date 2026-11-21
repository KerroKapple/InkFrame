// 参考库读取契约：给一个本机文件夹，读出里面的条目。
//
// 实现按图库格式各写一个适配器（现在只有 ai-pose-gallery-zh，见
// services/reference_library/）；以后接别的图库再加一个实现，调用方不变。
import '../models/reference_item.dart';

/// 一次读取的结果（不可变）。
sealed class ReferenceLibraryLoad {
  const ReferenceLibraryLoad();
}

/// 读到了。[skippedFiles] = 存在但读不出来的数据文件名（其余类别照常）。
final class ReferenceLibraryLoaded extends ReferenceLibraryLoad {
  const ReferenceLibraryLoaded(this.items, this.skippedFiles);

  final List<ReferenceItem> items;
  final List<String> skippedFiles;
}

/// 这个文件夹不是参考库：不存在，或一个可用的数据文件都没有。
final class ReferenceLibraryNotFound extends ReferenceLibraryLoad {
  const ReferenceLibraryNotFound();
}

abstract class ReferenceLibraryReader {
  /// 读 [rootPath]（图库根目录的绝对路径）。不抛异常：读不到返回 [ReferenceLibraryNotFound]。
  Future<ReferenceLibraryLoad> load(String rootPath);
}
