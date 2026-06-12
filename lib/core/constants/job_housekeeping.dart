// jobs 表清理策略常量（PRD §21 retention）。

/// 终态 job 保留时长——超期由启动 purge 清除。
const Duration kJobRetention = Duration(days: 30);

/// 每画布终态 job 上限——超限的最旧行由启动 purge 清除。
const int kJobPerCanvasCap = 500;
