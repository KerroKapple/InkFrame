# 设计：风格泳道（Style Lanes）落地 — InkFrame v2

- 日期：2026-06-23
- 作者：Kerro（经 Claude 协助）
- 状态：已批准（自主执行）
- 关联：PRD §3.7 / §4.4 / §6.4 / §7；ARCHITECTURE §4
- 范围口径：Approach 1 —— MVP 垂直切片（"泳道能端到端工作"）

## 1. 背景与问题

`style_lanes` 表、`nodes.lane_id`、`canvas.lane_direction`、`canvas.base_style_prefix/suffix`、
`StyleLaneRepository` + `styleLaneRepositoryProvider`、`NodeRepository.create(laneId:)`
**已全部存在且测试覆盖**（见 `lib/storage/schema/001_init.sql`、
`lib/storage/repositories/postgres_style_lane_repository.dart`、`lib/core/di/repositories.dart`）。

但**消费这套数据的 UI / 状态 / 逻辑层全部缺失**：

- `styleLaneRepositoryProvider` 是死代码——除 DI 定义与仓储测试外无人 import。
- `CanvasNode` 模型没有 `laneId` 字段；`canvas_view.dart` 用扁平 `Stack` 渲染，无泳道概念。
- `generation_controller.dart` 直接拿 `typeConfig['prompt']` 当 `fullPrompt`/`userPrompt`，
  **PRD §7.4 的拼接公式（基底前缀 + 泳道风格 + 关联文本 + 用户 prompt + 基底后缀）完全未实现**。
- 节点拖动位置只在内存（`CanvasNodesController.moveNode` 不落盘），
  这是"按节点中心点归属泳道"的前置依赖。

**目标**：把泳道从"一张表 + 一个没人用的仓储"做成端到端可用的特色功能——
画布上能看见泳道、能拖节点进出泳道、能增删改泳道、生成时泳道风格真正注入 prompt。

## 2. 范围

### 2.1 纳入（In Scope）

1. **数据/状态层**
   - `CanvasNode` 增加 `laneId`（来自 `lane_id`）+ `ignoreLaneStyle` 便捷读取（`type_config['ignore_lane_style']`）。
   - 新 `StyleLane` 不可变 UI 模型 + `fromRow`（与 `CanvasNode` 同风格，手写，不引 freezed/codegen）。
   - 新 `canvasLanesControllerProvider`（`AutoDisposeAsyncNotifierProviderFamily<…, String>`），
     CRUD 委托 `StyleLaneRepository`，与 `CanvasNodesController` 同样的"乐观改内存 + 失败回滚"策略。

2. **几何与色彩（纯函数，可单测）**
   - `lane_geometry.dart`：由有序泳道列表 + 方向 + 各自 `size` 计算每条泳道矩形（累计偏移），
     以及 `laneIdAtPoint(center)`（节点中心落在哪条泳道）。画布固定 4000×4000。
   - `lane_tint.dart`：PRD §7.3 关键词→hex 推断（5 组，中英双语词表，按表序取首个命中、不叠加）；
     `tint_color` 非空时用户色优先。含 hex↔`Color` 解析。**双语词表是内部匹配逻辑，英文+中文常量写在代码里，不入 ARB。**

3. **渲染**
   - `lane_background.dart`：`CustomPaint` 背景层，置于连线层/节点层**之下**。每条泳道底色叠加（8–12% 透明度），
     泳道间 40px 渐变过渡带 + 1px 细线。横向（带沿 Y 堆叠，跨满 X）/竖向（带沿 X 堆叠，跨满 Y）。
   - `lane_title_bar.dart`：泳道标题条（横向在顶、竖向在左），半透明背景，显示 label + 编辑/菜单按钮。

4. **交互**
   - 拖动落点：`CanvasNodesController` 在拖动结束时
     (a) 持久化 `position_x/y`（`NodeRepository.update`），
     (b) 按中心点算归属泳道，`lane_id` 变化则持久化。**这并入并解决"拖动位置不入库"依赖。**
   - 泳道 CRUD UI：新增（工具栏 "+"，追加到末尾、`sort_order` 递增）、
     编辑（双击标题条弹 `lane_edit_dialog`：名称 / 风格描述 / 背景色 + 重置为自动）、删除（菜单 + 确认）。
   - 方向切换：工具栏按钮，持久化 `canvas.lane_direction`（`CanvasRepository.update`）。

5. **Prompt 注入（核心价值）**
   - 新 `prompt_assembler.dart`：纯函数实现 §7.4 公式。
     段间 `, ` 分隔（上段以标点结尾则不加）、空段跳过、`ignoreLaneStyle` 时泳道段为空。
   - `generation_controller.submitFromConfigNode` 改为调用 assembler 组装 `fullPrompt`：
     读 canvas 基底前后缀、读节点所属 lane 的 `style_prompt`、解析连入文本节点内容
     （沿用 `_resolveRefImages` 的 incoming-data-edge 模式，按 `edge.created_at` 升序），
     `userPrompt` 仍存节点自身 prompt。
   - inspector 底部实时显示拼接预览（§7.4）；新增"忽略区域风格"开关（写 `type_config.ignore_lane_style`）。

6. **i18n**：所有新 UI 文案 en + zh 同步入 `app_en.arb` / `app_zh.arb`，键集对齐。

7. **测试（TDD）**：几何 / 色彩 / assembler 纯函数单测；lanes controller 单测（mock repo）；
   `CanvasNodesController` 扩展拖动持久化+归属单测；泳道渲染 + 拖动归属 widget 测试。

### 2.2 不纳入（Deferred，附理由）

- **拖拽分界线调整泳道大小**：编辑弹窗里用数值输入改 `size` 替代；拖拽 resize 是体验打磨，留二期。
- **拖标题条重排序**：本期按创建顺序；重排可后续加菜单"上移/下移"或拖拽。
- **双击分界线折叠泳道**：纯视觉折叠，非核心。
- **§7.7 项目基底风格编辑器 + 7 个预设**：assembler **会读** `base_style_prefix/suffix`（为空则跳过），
  但编辑这两个字段的顶栏弹窗 + 预设是独立特性，单独立项。
- **性能省电档降级为纯实线**：依赖尚未落地的性能档位系统（PRD §3.9）。

> 以上 deferred 项在代码注释与本 spec 显式标注，避免被误读为"已全做"。

## 3. 架构与文件

```
新增：
  lib/features/canvas/models/style_lane.dart                 # StyleLane 模型 + fromRow
  lib/features/canvas/util/lane_geometry.dart                # 泳道矩形 + laneIdAtPoint（纯函数）
  lib/features/canvas/util/lane_tint.dart                    # 关键词→hex 推断 + hex 解析（纯函数）
  lib/features/canvas/providers/canvas_lanes_controller.dart # 泳道集合 CRUD（AsyncNotifierFamily）
  lib/features/canvas/widgets/lane_background.dart           # CustomPaint 背景层
  lib/features/canvas/widgets/lane_title_bar.dart            # 标题条 overlay
  lib/features/canvas/widgets/lane_edit_dialog.dart          # 新建/编辑弹窗
  lib/features/canvas/widgets/lane_toolbar.dart              # +泳道 / 横竖切换 工具条
  lib/features/generation/services/prompt_assembler.dart     # §7.4 拼接（纯函数）

修改：
  lib/features/canvas/models/canvas_node.dart                # +laneId +ignoreLaneStyle
  lib/features/canvas/providers/canvas_nodes_controller.dart # moveNode→落盘 + 归属泳道
  lib/features/canvas/widgets/canvas_view.dart               # _CanvasStage 接入泳道层 + 工具条
  lib/features/canvas/widgets/image_config_inspector.dart    # 拼接预览 + 忽略区域风格开关
  lib/features/generation/generation_controller.dart         # 用 assembler 组装 fullPrompt
  lib/l10n/app_en.arb / app_zh.arb                           # 新 UI 文案
```

**SOLID / DI 约束**（CLAUDE.md）：

- 控制器只依赖抽象 `StyleLaneRepository` / `CanvasRepository`，经 Riverpod provider 注入；单测用 override 打 mock。
- 纯函数（geometry / tint / assembler）零 Flutter UI 依赖（geometry/tint 仅用 `dart:ui` 的 `Offset/Rect/Color`），可纯单测。
- 零硬编码样式：泳道底色由 `tint_color` 数据驱动；其余视觉（标题条背景、分界线、间距）走 design token。
- 零硬编码用户文案：全部经 `context.l10n`。

## 4. 关键数据流

### 4.1 渲染

`_CanvasStage` 内 `InteractiveViewer → SizedBox(4000²) → Stack`，自底向上：
`LaneBackground(CustomPaint)` → 连线层 → 节点层 → 边删除按钮 → `LaneTitleBar` overlay。
泳道与节点同坐标系，随平移缩放一起变换。`canvasLanesControllerProvider(canvasId)` 提供有序泳道；
`lane_geometry` 把它们算成矩形。

### 4.2 归属与持久化

`NodeCard.onDragEnd(totalDelta)` → `CanvasNodesController.moveNode`：内存更新位置 →
（拖动结束）`NodeRepository.update(position_x/y)` →
`laneIdAtPoint(中心)` 算新 lane → 若变化则 `update(lane_id)`。失败回滚内存并冒泡（UI toast）。

### 4.3 Prompt 注入

`submitFromConfigNode`：
```
base = canvasRepo.findById(canvasId) → base_style_prefix / base_style_suffix
lane = node.laneId==null||ignoreLaneStyle ? '' : laneRepo.findById(laneId).style_prompt
texts = incoming data edges → 源文本节点内容(type_config['text'] ?? label)，按 edge.created_at 升序
full = assemblePrompt(base.prefix, lane, texts, userPrompt, base.suffix, ignoreLaneStyle)
jobs.create(fullPrompt: full, userPrompt: userPrompt, …)
GenerationTask(prompt: full, …)
```
读 canvas / lane / text 失败时**降级为 userPrompt**，不阻断生成（与现有 refs best-effort 一致）。

## 5. 错误处理

- 仓储错误统一 `InkError`（`guard()` 已封 `PgException→LocalIOError`）；控制器回滚内存并 rethrow，UI 出 toast。
- 泳道几何对空列表 / 越界点返回"无泳道"（`null`），不抛。
- assembler 是纯函数，永不抛；输入全为 String/List，空安全。

## 6. 测试策略（TDD，先红后绿）

| 层 | 测试 | 关键用例 |
|---|---|---|
| geometry | `lane_geometry_test.dart` | 横/竖矩形累计、点命中边界、空列表、越界→null |
| tint | `lane_tint_test.dart` | 5 组关键词命中、首个命中优先、中英双语、hex 解析、无命中→null |
| assembler | `prompt_assembler_test.dart` | 全段、空段跳过、标点结尾不加逗号、ignoreLane、多文本顺序 |
| lanes ctrl | `canvas_lanes_controller_test.dart` | create/update/delete 乐观更新 + 失败回滚（mock repo） |
| nodes ctrl | 扩展 `canvas_nodes_controller_test.dart` | 拖动结束落盘 position；跨界改 lane_id；DB 失败回滚 |
| 渲染 | `lane_background_test.dart` / widget | 泳道层存在、拖节点进泳道后归属更新 |

`testWidgets` 中**禁止 await 真实 `dart:io`**（用 `*Sync` / mock），遵循既有约定。

## 7. 验收标准（DoD）

1. `flutter analyze` 零 issue；`custom_lint` 不新增告警。
2. 新增 + 现有测试全绿；i18n en/zh 键集对齐（CI parity 通过）。
3. 画布可见泳道（横/竖）、可增删改、可切方向。
4. 拖节点跨泳道后归属切换并落盘；位置落盘（刷新画布不丢位）。
5. 生成时泳道 `style_prompt` 真正进入 `fullPrompt`（inspector 预览可见、job 记录可验）。
6. 无硬编码样式 / 文案。
```
