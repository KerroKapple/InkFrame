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
