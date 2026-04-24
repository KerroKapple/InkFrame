# InkFrame UI 迁移路线图（CineFlow 风格）

> 2026-04-24 拟定。依据 `docs/superpowers/analysis/2026-04-24-cineflow-canvas-ux-patterns.md`
> 决策基线：节点模型保留 config/result 二段式；画布底层自研增量；Undo/Redo + Group 跳
> 目标：Sprint 1 token 已做；Sprint 2-5 分阶段落地 CineFlow 结构

## 硬决策（已拍板）

- ✅ **节点模型**：二段式 config/result 保留。Inline panel 挂 **config node**（替代右侧 Inspector）；result node 维持缩略展示
- ✅ **画布底层**：自研增量加 handle / marquee / snapping / bezier 到 InteractiveViewer + 自绘
- ✅ **Undo/Redo + Group**：跳，独立大 Sprint 未来再立项

## Sprint 序列

| # | Sprint | 核心交付 | 预计工作量 | 依赖 |
|---|---|---|---|---|
| 1 | **Token 对齐**（已完成） | InkColors 10 新 slot + dark/light 按 CineFlow hex 对齐 + primary → Apple Blue | 1 人日 | — |
| 2 | **Inline Panel v1** | 右侧 Inspector 砍掉；config node 下方浮出 inline 操作面板（portal + 随画布 transform 跟动） | 2-3 人日 | Sprint 1 tokens |
| 3 | **Bottom Toolbar** | 右下 FAB 砍掉；画布底部中央横排工具条（Image / Video / Text + ViewportControls 左下） | 1-2 人日 | Sprint 1 |
| 4 | **Bezier Edge** | 直线边 → CustomPainter bezier + 5 色渐变 + 3 态（default / highlighted / selected） | 1-2 人日 | Sprint 1 |
| 5 | **画布交互增强** | Multi-select + marquee；Shift+Drag = pan；handle drag-to-connect → NodeCreationMenu；伙伴边自动创建 | 3-5 人日 | Sprint 2, 4 |
| 5.5 | **Slash / @mention**（可选） | Prompt textarea 打 `/` 出命令菜单；打 `@` 出 asset 联想 | 2-3 人日 | Sprint 2 |

## Sprint 间独立性

每个 Sprint 产出**可 merge 可 revert 的独立 PR**。具体约束：

- **Sprint 2**（inline panel）依赖 Sprint 1 的 `accentHover / borderSubtle / surface4` slot。Sprint 1 不 merge 则 Sprint 2 起不来
- **Sprint 3**（bottom toolbar）和 Sprint 2 **可以并行**（没有代码重叠）——可以两个 PR 同时开
- **Sprint 4**（bezier edge）独立于 Sprint 2/3
- **Sprint 5**（交互增强）依赖 Sprint 2（多选需要配合 inline panel 选中态）+ Sprint 4（handle 拖动连线依赖新 edge 画布）
- **Sprint 5.5**（slash/@）依赖 Sprint 2 的 textarea

## 明确跳掉的 CineFlow 特性（原因备案）

| 特性 | 跳的原因 |
|---|---|
| Undo/Redo (Ctrl+Z) | 要命令模式/事件溯源贯穿所有 mutation，独立大 Sprint |
| Group (Ctrl+G) | 要加 group 表 + 嵌套选中 + 折叠 UI，独立大 Sprint |
| Cursor overlay / OnlineUsers / 协作 | InkFrame 是单机 desktop，无后端，产品定位不需要 |
| Firebase/Supabase 存储 | InkFrame 走嵌入 PG + 本地 AppPaths，架构决策已定 |
| Network Grid 切分 2×2 3×3 | CineFlow 独有业务能力，InkFrame PRD 未定义 |
| Batch results carousel UI | 数据层已备（batch_results 表），UI 等 Sprint 6+ |
| Upload 下拉 / Ctrl+U | InkFrame 走 asset browser 不从工具条上传，流程差异 |

## Plan 文档存放

- `docs/superpowers/plans/2026-04-24-ui-sprint-1-token-migration.md`（Sprint 1，已做）
- `docs/superpowers/plans/2026-04-24-ui-sprint-2-inline-panel.md`（Sprint 2，本次要写的）
- `docs/superpowers/plans/2026-04-24-ui-sprint-3-bottom-toolbar.md`（Sprint 3，骨架）
- `docs/superpowers/plans/2026-04-24-ui-sprint-4-bezier-edge.md`（Sprint 4，骨架）
- `docs/superpowers/plans/2026-04-24-ui-sprint-5-canvas-interactions.md`（Sprint 5，骨架）

Sprint 3-5 先只写 goal + 出入口定义 + 粗粒度任务清单，具体任务级 step 在上 Sprint 即将开工时再写详细版（拒绝过度提前规划）。
