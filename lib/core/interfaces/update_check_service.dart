// UpdateCheckService：应用内检查更新的抽象契约（UPD-1）。
//
// 实现负责取远端已发布版本并与本机版本比较;失败路径只允许抛 InkError 子类
// （NetworkError / ProviderError / UnknownError）,调用方按 AsyncValue 消费。
import '../models/update_check_result.dart';

abstract class UpdateCheckService {
  /// 检查是否有更高版本。无网/远端失败抛 InkError,由调用方决定静默或轻提示。
  Future<UpdateCheckResult> check();
}
