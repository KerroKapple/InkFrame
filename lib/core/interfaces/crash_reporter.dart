// CrashReporter 抽象：把未捕获错误落盘为崩溃文件，供事后诊断（LB-18 诊断包前置）。
//
// 契约：
//   - report 只接受 错误 + 栈；刻意【不】接受任何 extra / 键值上下文——
//     崩溃文件必须结构性地杜绝夹带潜在敏感数据（无 prompt / key / token 等混入）。
//   - 实现同步落盘并 flush，且做文件数轮转（只保留最近若干个）。
//   - report 自身不吞异常：写盘失败向上抛出，由最外层"最后一道防线"处理器统一兜底。
abstract class CrashReporter {
  /// 记录一次未捕获错误：错误 + 栈 + 应用版本 + 时间戳，写入崩溃文件并落盘。
  void report(Object error, StackTrace? stackTrace);
}
