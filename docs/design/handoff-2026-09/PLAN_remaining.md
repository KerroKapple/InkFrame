# InkFrame 视觉重建 · 剩余全部计划（2026-09-28 定稿）

已合入：PR #234 结构层；PR #235 V0 token / V1 壳 / V2 Studio / V3–V5 画布 / V7 画廊 / V9 命令面板 / 设置浮层。
本文覆盖其余全部工作，按依赖排序。每个 PR 独立、可回退。

流程不变：静态复刻（稿原文假数据）→ 并排像素比对 → 用户验收 → 接线 → 重比 → 无字段项逐条标偏离。
每屏两张截图：1600×1000 与 960×600。CJK 超长文本测试随每屏补。

---

## P1 · 风格泳道（feat/v1-lanes，进行中）

稿：`InkFrame Lanes.html`。Workspace v2 上的 11px 灰字泳道画法作废。

六项改动全做：标题栏两行含 stylePrompt · 道首 3px 满饱和色轨 · 节点底部「继承 X」标注 · 折叠收 36px · 标题栏宽 268 / min(道宽-24, 240) · 色板读 lane_tint 常量。
编辑框四项：名称 / 风格描述 / 底色（自动 + 5 色，自动下方注明命中词与推断值）/ 预览。**不做**预设 chip、厚度滑块。
工具栏方向键加「横向 / 竖向」文字标签。
顺带修 BOARD P2-3（窄竖道按钮不可命中）。
画布 golden 会红：预期，PR 说明重铸原因。
无字段：无。差异升高先查 stylePrompt 撑破两行。

## P2 · 序列 A（序列 lens，只读）

稿：`InkFrame Timeline.html`（2026-09-25 默认 EDL 版）。
接：叙事链列表（短时间码 MM:SS）· 节目监视器 · V1 只读轨 · 标记轨（场次标记由链推）· 播放头 · 34px/s 可缩放。
画但只读：裁切手柄（两端 4px 琥珀条）。**不接**拖拽排序、裁切写回、A1 轨、交付面板。
交付面板位置放空态：「交付功能随 P5 到来」+ 目标软件分段选择器禁用态。
三条铁律：Player 去自动播放，`isTabVisible(sequence)` 变 false 时 pause，回来不续播（测试一条）；门控看 `ShellState.project`（收 BOARD 210）；默认 EDL。
标签在 canvasId == null 时禁用 + 「请先打开一个画布」，不 watch 仓储。
无字段：入出点 / 手柄 / 音轨 / 断点标记（用户手打的 M）。

## P3 · 镜头语言数据模型（唯一补建的模型）

BOARD 211。四字段进 video config 的 type_config：`shot_size`（景别）/ `camera_angle`（机位角度）/ `camera_motion_strength`（运镜幅度 0–1）/ `focal_length_mm`（焦段）。
枚举值（zh / en 各一份 ARB）：
- 景别：远景 ELS / 全景 LS / 中景 MS / 近景 MCU / 特写 CU / 大特写 ECU
- 机位角度：平视 Eye Level / 俯拍 High / 仰拍 Low / 鸟瞰 Bird's Eye / 荷兰角 Dutch
- 运镜方式（已有 `camera` 字段，补齐枚举）：固定 Static / 推镜 Dolly In / 拉镜 Dolly Out / 左摇 Pan L / 右摇 Pan R / 上摇 Tilt Up / 下摇 Tilt Down / 左移 Truck L / 右移 Truck R / 跟拍 Tracking / 升 Pedestal Up / 降 Pedestal Down / 环绕 Arc
- 焦段：14 / 24 / 35 / 50 / 85 / 135 mm
迁移一条，默认全 null（不显示）。
消费点四处同 PR 接上：检查器「镜头运动」组四行 · 画廊右栏「镜头语言」行 · 序列监视器底部叠字 · 提示词条摘要。
提示词注入：四字段非空时按 `{景别}, {运镜}, {角度}, {焦段}mm lens` 英文前置到 prompt（provider 不支持 camera 能力位时只注入不下发参数）。
不做：模型名 / fps（BOARD 212，provider 元数据问题，另议）。

## P4 · 批量结果 + 角色（V8）

稿：`InkFrame Batch and Characters.html`（danger 已同步 #D25A4A）。

批量五项：slot 按 width/height 真比例 · 露出 seed · 显式动作（转正 / 当前 / 重跑 / 取消，生成中 ⎘ 置灰）· 足尺对比浮层（←→ ↵ Esc；「叠加对比」模式**不做**，标偏离）· 失败 slot 出 errorCode 原串。
四种 slot 状态测试：success / promoted / error / generating。

角色三块：
- 检查器挂载区保留原样，加「管理」链接。
- 角色库进画布左栏「角色」页：36×36 首图 + 名 + 「N 张参考图 · M 处引用」+ ⋯（编辑 / 改名 / 删除）。rename / delete 直接接现有控制器。删除确认文案写「可从回收站恢复」（softDelete 保资产）。
- 编辑框 520：名称 / 描述 / 参考图（序号 + 备注 + 删 + 拖排，末位添加格，上限沿用 provider maxRefImages）/ 被引用节点。
控制器补四个薄方法：setDescription / addReferenceImage / removeReferenceImage / reorderReferenceImages。多图落盘 `{id}-{n}`。不改仓储、不加迁移。
无字段：参考图「备注」文字（不做，格下只留序号）。

## P5 · 首启向导

稿：`InkFrame Screens.html` 屏 4 左。
三步：欢迎 / 配置密钥 / 首个项目。第二步 Provider 单选（Gemini / fal.ai / DashScope）+ Key 输入 + 验证 + 成功态；第三步「空白 / 短剧示例」。
底部「已检测：32 GB · 独显」无硬件探测，**不画**；改成「可在设置 › 性能中调整」一句。
onboardingCompleted 语义不变；跳过按钮语义 = 完成但不配 Key，Studio 引导条接手。

## P6 · 交付 B

依赖 P2 + P3。
EDL CMX3600 写出器（V1 单轨、24fps、TC 起点 01:00:00:00 可改）· 媒体导出 `{序号3位}_{镜头名}.mp4` 保持源 · 手柄 ±12 帧（写 EDL 不改媒体）· metadata.json（含 P3 四字段）· 交付设置按项目持久化 · 交付前检查四条 · 导出历史（渲染队列第三标签，收 IA B4）。
目标软件分段：Resolve / Premiere 出 EDL；剪映出草稿 JSON（PRD P1）；Final Cut 禁用 + 「FCPXML 待支持」。
断点 → 标记：无用户标记字段，只导场次边界，标偏离。
导出进行中锁其余标签（替代原 barrierDismissible）。

## P7 · 收尾（一个 PR）

- 内置示例并入 Studio「新建项目 › 短剧示例」，删 built_in_showcase_screen 与 ShellOverlay.showcase。
- 画布空状态按中性灰重画（canvas_empty golden 这次该变）。
- 启动错误页按中性灰重画，保留全部诊断信息。
- 回收站对话框改浮层样式（复用设置浮层壳，720×520）。
- 设置补三页壳：快捷键（只读列表，读现有 Shortcuts 表）/ 性能（现有性能档位）/ 网络（现有代理设置）；有后端才画，没有的行不留空位。
- 全仓 grep 旧暖色 hex 与 serif 家族名归零，测试钉死。

---

## 不做清单（明确关闭，别再问）

对比浮层「叠加」模式 · 画廊悬停自动播 / 收藏 / 列表视图 · Studio 归档 / 最近打开 / 存储占用 · 模型名 / fps 显示 · 跨画布搜镜头 · 设置项搜索索引 · 硬件探测 · FCPXML · 用户手打标记 · A1 音频轨 · 提示词写入 metadata 开关（默认写，不给开关）· 画廊筛选 LRU（项目上百再议）。

## 验收口径

差异 ≤ 2.5% 且余量全为字形 → 静态通过。接线后差异上升只接受三类原因：无字段项、播种数据量、真实数据长度；第三类必须附超长中文测试。任何 golden 变红 PR 里写原因。

---

## 补充拍板（2026-09-29，执行时会卡住的决定；正文不重写）

**P2 序列 A**
- 静态复刻只做 Timeline 稿的上半 + 序列区；交付面板位置用空态占位（宽照稿 320，内容一行「交付随 P6 到来」+ 禁用的目标软件分段选择器）。
- 播放头拖动可以接，跳转只改 Player 位置，不写库。
- 叙事链拖排不接，列表行的 ⠿ 拖柄不画。
- 监视器叠字四段（序号 · 运镜 · 景别 · 模型）里景别 P3 才有，先出三段。
- 差异口径放宽到 3%（上半 + 序列两块拼一屏，文字密度高）。
- P2 之前：夹具节点下移 30px，别让画布 golden 带着「贴道顶的节点被标题栏压角」当基线。

**P3 镜头语言模型**
- 迁移只加列不动旧数据，四字段全 null。
- 检查器四行 = 下拉（景别 / 角度 / 焦段）+ 滑块（幅度 0–1，步进 0.05）。
- 已有 `camera` 字段的枚举扩到 13 项；旧值映射：推进→推镜，其余按 ARB 表。
- 没有稿，验收看检查器 1600×1000 截图一张。

**P4 批量 + 角色**
- 对比浮层 1080 宽；slot 少于 4 时列数随实际数，不留空格。
- 角色库空态：「还没有角色 · 从节点结果「存为角色」开始」。
- 参考图上限读 provider maxRefImages，超出时添加格禁用。

**P5 首启向导**
- 三步进度可回退（点已完成步）。
- 验证失败态：Key 底线变 danger，下方一行错误码原串。
- 第三步「短剧示例」= 现有 showcase 内容建成真项目，为 P7 删 showcase 铺路。

**P6 交付 B**
- EDL 写出器带三条黄金文件测试（单镜 / 带手柄 / 含占位空隙），文件入库对比。
- 导出中锁标签：标签条整体 IgnorePointer + 导出标签进度环，Esc 不中断。
- 导出历史存 exports 表（新迁移，含路径、时间、目标软件、成功否）。

**P7 收尾**
- 删 showcase 时 `ShellOverlay` 枚举只剩 settings，测试里所有 showcase 用例删不搬。
- 回收站浮层 720×520 复用设置浮层壳，左侧无导航。

**通用**
- 每 PR 从 main 新开分支，合入即删。
- 差异升高的三类原因之外一律回来找用户。
- 「不做清单」的东西碰到了就跳过，不记 BOARD。
- 每屏静态复刻到验收点报数字，用户看图。
