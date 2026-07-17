// DiagnosticsBundleService：诊断包导出契约（LB-18）。
//
// zip 内容：info.json（版本/schema/平台/时刻）+ logs/*（含 pg.log）+ crashes/*
// + config 白名单（preferences.json / custom_providers.json——**绝不整扫 config/**，
// macOS Debug 的明文 secrets.dev.json 由白名单结构性排除）。
// 落盘纪律同 LB-11/22：.partial → 原子 rename；失败清 partial 抛 LocalIOError。
abstract class DiagnosticsBundleService {
  Future<void> exportBundle({required String targetPath});
}
