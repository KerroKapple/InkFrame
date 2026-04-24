# CineFlow 画布 UX 模式分析

> 分析时间 2026-04-24，源：`/Users/kerro/Projects/CineFlow/src/components/canvas/` + `/nodes/`
> 目的：为 InkFrame 向 CineFlow 风格迁移提供结构认知基线（不含实现细节）

## 1. 画布级布局

**四角/边位置**
- **底部中央**：水平主工具条——3 个彩色类型按钮（Image / Video / Text）+ Upload 下拉 + 分隔符 + Origin/Fit-All/Zoom 控件。Framer Motion 弹簧动画 + hover/tap 微缩放。
- **左下**：`ViewportControls` 自定义缩放按钮（替代 React Flow 默认）
- **左上 / 右上**：无 floating toolbar（InkFrame 现状也是这样，右侧面板是父 layout 的一部分）
- **画布四边没有持久 timeline / ChatPanel**，一切浮层化

**节点创建触发**（双机制）
1. **底部工具条类型按钮** → `pipeline.addNode()` 在视窗中心 + 随机 offset
2. **从节点 handle 拖连接线丢到空白画布** → `NodeCreationMenu` 在光标处弹出，按源节点类型过滤出可创建的目标节点类型（`menuItemsConfig`）

## 2. 节点卡片解剖（以 ImageNode 为例）

结构由 `NodeShell` 包装，内部分层：
- **标题栏**：Shot ID + title（可 inline 编辑，受 `titleEdit` trait 控制）
- **媒体预览**：
  - 响应式 LOD：有效宽度 ≤ 600px 用缩略图，否则用原图（`effective = nodeWidth × zoom × devicePixelRatio`）
  - 远端失败回落 `getLocalPreview()`
  - Drag-over 时显示虚线边框 + "释放以添加" overlay
- **状态覆盖层**（压在 media 上）：
  - `status='uploading'`：spinner + 进度条（0-100）
  - `status='error'`：error badge + 错误文本
  - 成功：checkmark
- **操作工具条**（右上角）：Save/Download（按 aspectRatio 裁剪后下载）、Maximize（全屏预览 modal）、右键菜单（生成视频、2×2 / 3×3 网格切分）
- **选中态**：React Flow CSS class 即可，无显式 border——依赖主题变量 `cineflow-accent`
- **批量结果 carousel**（`batchResults` 数组有值时）：滚动选 4-6 张变体之一提升为主图

## 3. 内联面板（NodeInlinePanel）—— 最关键

**定位**
- **固定在节点下方**：面板 x-center 对齐节点 x-center，y = `node.bottom + 16px`
- **边界处理**：近右边仅 clamp left，**没有 flip 到上方**的逻辑（可能被推出视窗）
- **通过 `createPortal` 挂到 `document.body`**，不受 canvas 层级约束
- 尺寸**固定不随缩放**（CSS 像素恒定），定位随 viewport 变化——`MutationObserver` 监听 `.react-flow__viewport`，`requestAnimationFrame` 节流

**触发**
- `isOpen` 由父组件控制（选中节点或 double-click 进 inline 编辑态时打开）
- **Escape 或点 canvas 空白关闭**——点击外部不自动关

**内容自上而下**
1. **Prompt textarea**：自动高度 60-200px。`Enter` 提交（`Shift+Enter` 换行），`Esc` 关面板。
2. **Slash 命令菜单（打 `/` 触发）**：6 个预设（grid-9 / grid-4 / 灯光 / 三视图 / 预测后 / 预测前），方向键导航，Enter/Tab 选中。
3. **Asset 联想菜单（打 `@` 触发）**：列出 edges 连来的参考图 + asset library，方向键 + Enter。选中后以 `{url, type, ...metadata}` 注入到 `assetMentions[]`。
4. **底部控制条**：
   - Model 下拉
   - Aspect ratio 选择
   - Quality/Resolution 下拉
   - Batch count 数字框
   - Camera popover（cameraBody / lens / focalLength / aperture）
   - Advanced popover（negative_prompt / seed / steps / CFG / 运镜栅格）
   - Reference images 缩略区（2-4 张横排，可上传/粘贴加）
5. **Generate 按钮**（右下）：生成中或节点锁定时 disabled

**交互**
- **非 modal**：面板打开时画布仍可 pan/zoom/选别的节点
- **不 collapse**：面板总是 "展开" 态，弹窗/popover 叠加在 `z-[1010]`

## 4. 边（connection）

**视觉三态**（StyledEdge.tsx）
| 态 | 样式 |
|---|---|
| default | Bezier 曲线，5 色渐变笔触（粉→紫→蓝→青），1.5px，opacity 0.75，6px 软辉光 opacity 0.08 |
| highlighted（源/目的节点选中） | 同渐变但更粗 2.5px，opacity 0.85，8px 辉光 opacity 0.15 |
| selected（边被点） | 纯金黄 3px，14px 重辉光 opacity 0.25，filter blur=4 |

**无箭头**（`MarkerType.ArrowClosed` 默认被 StyledEdge SVG path 覆盖）

**创建**
- 源 handle 拖出 → 自定义 bezier 跟光标，`SNAP_RADIUS = 40px` 内自动吸附
- 丢目标节点：自动连接
- **丢空白画布：自动弹 `NodeCreationMenu`**
- 多选伙伴边：3+ 节点同选时，从一个拖会自动创建到所有同选节点的边
- 校验：无自循环、无重复边、group 节点不可作 target

## 5. 选择 + 键盘

**多选**
- Shift+Click / Cmd+Click：加/减
- **左键拖拽 marquee**（`SelectionMode.Partial`：擦过即选）
- Shift+Drag：改为 pan canvas

**快捷键**
| 组合 | 动作 |
|---|---|
| Ctrl/Cmd+G | 组合选中节点 |
| Delete / Backspace | 删（优先边） |
| Ctrl+Z / Ctrl+Shift+Z | 撤销/重做 |
| Ctrl+U | 上传 asset |
| Esc | 关面板 + 取消全选 |
| Enter（面板内） | 提交生成 |
| ↑↓（菜单内） | 导航 |

## 6. Asset 引用

- **边引用**：图节点连图节点时，边自动携带引用——`connectedRefImages` 实时从边收集，追加到参考图列表
- **手动 vs 自动**：`manualRefImages`（用户加）vs `connectedRefImages`（边来），边为空时用手动
- **@mention**：prompt 里打 `@` 弹 asset 菜单 → `InjectedAssetData` 含 `referenceImage` URL + 元数据
- **Generate 时**：若 `reference_images` 已填，过滤 mentions 只保留实际用到的

## 7. 缩放响应

- 缩放范围 0.1x - 4x
- **默认滚轮**：上下平移画布；**Ctrl+滚轮**：缩放
- **拖拽平移**：Shift+左键 / 中键 / 右键拖
- **内联面板**：固定像素尺寸，不随 zoom
- **图片 LOD**：按有效像素宽度切换缩略/原图

## 8. 动效

- 工具条按钮：hover 1.05x，tap 0.95x（Framer Motion）
- Slash/@菜单：`scale 0.8→1 + opacity 0→1`，150ms
- 边：拖拽时实时更新 bezier，靠近节点时吸附
- 卡片内：`Loader2` spinner + 进度条 overlay
- Generate 按钮：文字切换 + disabled 态

---

## 与 InkFrame 的 3 大结构性差异

| 维度 | CineFlow | InkFrame 现状 | Flutter 移植含义 |
|---|---|---|---|
| 操作面板位置 | **节点下方内联**（`createPortal` + 绝对定位） | **右侧固定面板** | 需要：`Overlay` + `OverlayEntry` 做 absolute portal，监听节点位置变化 |
| 节点创建入口 | **底部中央横向工具条**（3 类型按钮 + upload） | **右下 FAB** | 从单 FAB 切横排 floating toolbar，用 `Row` 布局 |
| 边视觉 | **曲线 + 5 色渐变 + 3 态**（default/highlighted/selected） | **直线** | 自定义 `Path` 画 bezier + `Shader.linear` 做渐变 + `MaskFilter.blur` 做辉光 |

## 关键源码引用

- **面板定位**（NodeInlinePanel.tsx:592-601）：`x = rect.left + rect.width / 2 - DEFAULT_PANEL_WIDTH / 2; y = rect.bottom + PANEL_GAP;` — 锚定下方，无 flip 逻辑
- **Portal 挂载**（line 169）：`createPortal(..., document.body)` — 脱离 canvas 级联
- **多选 drag**（FlowCanvas.tsx:1152）：`selectionOnDrag={!shiftPressed}` — 左键拖 = 选，按 Shift 就变 pan
- **边三态**（StyledEdge.tsx:76-142）：三条件分支 `selected ? ... : highlighted ? ... : ...`，各自独立 gradient 定义
