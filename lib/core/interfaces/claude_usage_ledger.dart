// Claude 用量记账的写入口（客户端只依赖这一个方法）。
//
// 实现见 services/anthropic/in_memory_claude_usage_ledger.dart；UI 经
// core/di/anthropic.dart 的 claudeUsageLedgerProvider 读账。
import '../models/claude_message.dart';

abstract class ClaudeUsageLedger {
  void record(ClaudeUsageRecord record);
}
