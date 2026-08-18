// LB-23：ImageCache 字节上限。cacheWidth 收口后画廊 100 项工作集 ≈80MB
// 贴 Flutter 默认 100MB 上限，滚动即抖动淘汰；桌面内存充裕，上调换流畅。
// 条目上限 1000 不动（桌面场景先触字节限）。评估记录见 docs/perf-baseline.md。
const int kImageCacheMaxBytes = 256 << 20;
