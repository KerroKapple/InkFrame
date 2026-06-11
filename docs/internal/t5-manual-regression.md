# T5 手动回归清单

- [ ] 在 canvas 新建 video 节点 → Inspector 显示 prompt / duration / camera
- [ ] 点 Generate → 观察 result 节点占位（旋转圆）出现
- [ ] 等待 wanx-t2v 结束（~30s） → result 节点显示缩略图
- [ ] 点 result 节点 → 灯箱打开并播放视频
- [ ] 关灯箱 → 节点状态保持缩略图
- [ ] data edge 连 image → video config → Inspector 下方 inputs 列出
- [ ] 再次 Generate → task.mode 应为 imageToVideo（从日志确认）
- [ ] 删视频节点 → edges 级联软删
- [ ] 重启 app → 视频节点从 DB 水化，缩略 + 灯箱正常

## 自动化覆盖说明

CI 用 `very_good_coverage`（阈值 70）门禁覆盖率，exclude 清单见
`.github/workflows/ci.yml` 的 `exclude:` 行。本地对齐用 `scripts/coverage/report.sh`
（从 ci.yml 运行时抽取同一份 exclude，杜绝口径漂移）。

哪些低覆盖是「故意且已知」、而非隐藏缺口：

- **media_kit 依赖件**（`services/media_kit_*.dart` / `widgets/video_lightbox.dart` /
  `core/di/video_player.dart` / `core/di/thumbnail.dart`）：headless CI 无 GPU/native
  层，已在 CI exclude 中剔除，靠上面的人工回归清单兜底。
- **交互式 canvas painter**（`canvas_view.dart` / `edge_painter.dart` /
  `canvas_screen.dart` / `canvas_add_node_fab.dart` / `canvas_left_toolbar.dart`）：
  涉及手势命中、CustomPainter 绘制与拖拽，headless 难以有意义地断言行为，**仍计入
  覆盖率分母**——是「测得到但故意低」的已知缺口，靠人工回归覆盖，不写凑行假测试。
- **storage/repositories/postgres_\*** ：本地无 PG binary / `TEST_PG_URL` 未设时
  集成测试被 `markTestSkipped`，本地显示欠覆盖属正常；CI 起 `postgres:17` service
  真跑，CI-effective 实际更高。故本地 `report.sh` 数字是**保守下界**。
