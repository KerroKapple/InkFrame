# Canvas Performance Baseline (DoD #6)

> 对应 Beta DoD #6「性能基线文档化（节点规模 vs 帧成本阈值 + 守卫）」。
> 守卫实现：`test/features/canvas/canvas_scale_perf_test.dart`。

## 为什么这样测

`CanvasView` **不做视口裁剪**——`_CanvasStage` 用 `for (final node in nodes)
Positioned(RepaintBoundary(NodeCard(...)))` 把**全部**节点建进 4000×4000 的 `Stack`，
`EdgePainter` 画**全部**边。所以 build/layout/paint 成本随节点数增长，这正是
ROADMAP / PRD §3.9 记的「节点 > 200 帧率下降」的来源。

headless `flutter test` **无 GPU、无真实 vsync，测不到真实光栅帧率**。因此基线用无头环境
可稳定测量的**代理指标**：节点+边层 `pumpWidget`（build+layout+paint）的 CPU 耗时。
真实 GPU 帧率验证需 `integration_test` 在带 GPU 的 runner 上跑——属后续工作（见末尾）。

## 测量口径

- 4000×4000 surface（全部节点在视口内完成 layout，避免裁剪噪音）。
- 先 warmup 一帧吸收字体 / binding 一次性成本，再测。
- 场景镜像 `_CanvasStage` 的两个规模敏感层：`EdgePainter`（全部边）+ 节点层（全部
  `NodeCard`）。节点为 config + 无 `image_url`，渲染廉价且确定（不触发 `Image.file`）。
- 边为链式 `n-1` 条 `data` 边。

## 基线数据（2026-06，本机 Windows，indicative）

| N nodes | build+layout+paint (ms) | per-node (μs) |
|---------|-------------------------|---------------|
| 50      | ~221                    | ~4412         |
| 100     | ~228                    | ~2281         |
| 200     | ~397                    | ~1982         |
| 400     | ~646                    | ~1614         |

**判读**：约 ~200ms 是固定开销（4000×4000 surface + EdgePainter 全画布），其上每节点
边际成本随 N **下降**（4.4→1.6 μs/节点），总耗时 50→400（8× 节点）仅涨 ~2.9× ——
**亚线性，无二次爆炸**。CI（ubuntu）绝对值会与本机不同；关注的是**形状（亚线性）**与
**是否触发下方护栏**，而非绝对毫秒。诊断表每次 CI 都 print 进日志，可肉眼比对回归。

## 自动护栏（`canvas_scale_perf_test.dart`）

1. **诊断基线（print，不硬断言）**：N=50/100/200/400 的耗时表。与
   `job_queue_service_cancel_bench_test` 同 philosophy——只 print，避免环境抖动挂 CI；
   回归靠表格肉眼比对 + 下方两条硬护栏。
2. **灾难性回归上限（硬断言）**：400 节点 build < **8s**。本机实测 ~0.65s，留 ~12× 余量；
   仅捕获爆炸式退化（如误引入 O(n²) layout / 每节点全表扫描），不做微基准。
3. **`hitTestEdge` O(n+m) 确定性护栏（硬断言）**：N=M=3000 命中测试 < **50ms**（纯 CPU、
   零抖动、巨大余量）。这是画布规模敏感的纯函数热路径，与 job_queue perf group 的
   N=10000<50ms 粗线同形。

## 已知边界 / 后续

- 本基线**不覆盖真实 GPU 光栅帧率**——headless 无 GPU。subtle 的 2–3× 常数因子退化不会被
  8s 上限捕获（会体现在诊断表里，靠 CR 比对）。
- 真实「拖拽 / 缩放 200+ 节点时的掉帧」需 `integration_test` + `FrameTiming` 在带 GPU 的
  runner（macOS/Windows self-hosted 或 GPU ubuntu）上量化——列为发布流水线后续项。
- 若未来给 `_CanvasStage` 加视口裁剪（只建可见节点），本测试的「全部节点都 build」前提
  会变化，需同步更新场景与基线。
