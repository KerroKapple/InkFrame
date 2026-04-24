# CineFlow 设计原子库分析

> 2026-04-24 第二轮深读（首轮聚焦结构交互，本轮聚焦视觉原子）
> 源码路径：`/Users/kerro/Projects/CineFlow/src/`
> 目的：抽出 InkFrame 必须先搭的 **设计 primitive 层**，避免再次"位置对了但视觉一塌糊涂"

## 1. 核心视觉 DNA：毛玻璃三件套

**globals.css** 定义了整个 CineFlow 的视觉基底：

```css
.glass-card {
  @apply bg-cineflow-surface-1/95 backdrop-blur-2xl backdrop-saturate-150
         border-[0.8px] border-white/10 shadow-xl rounded-2xl;
}
.glass-pill {
  @apply bg-cineflow-surface-1/95 backdrop-blur-2xl backdrop-saturate-150
         border-[0.8px] border-white/10 shadow-xl rounded-full;
}
.glass-panel {
  @apply bg-cineflow-surface-1/90 backdrop-blur-xl backdrop-saturate-[1.25]
         border-[0.8px] border-white/[0.08] shadow-lg rounded-xl;
}
```

**共性**：
- `bg-surface-1/95`（95% 不透明）+ 半透明白边 `border-white/10` → 层叠感
- `backdrop-blur-2xl` = 40px 模糊（macOS Vibrancy 效果）
- `backdrop-saturate-150` = 1.5 倍饱和（让底层色更鲜艳）
- `shadow-xl` = 大阴影（0 25px 50px -12px rgba(0,0,0,0.25)）

**差异**：
| 类 | 圆角 | 用途 |
|---|---|---|
| glass-card | 16px (rounded-2xl) | 模态菜单、NodeInlinePanel、NodeCreationMenu |
| glass-pill | full round | 底部胶囊工具栏（但 FloatingToolbar 实际没用这个） |
| glass-panel | 12px (rounded-xl) | 次级浮层、popover |

**Flutter 实现契约**：
- `BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40))` + saturation matrix
- 或直接用 `flutter/foundation` 里没有原生 vibrancy，要用 `BackdropFilter` + 半透明 color overlay

## 2. 色板叠加模式

CineFlow **大量使用透明白叠加** 创造层次，不靠纯色变深：

| Tailwind | 含义 |
|---|---|
| `bg-white/[0.04]` | 极轻叠加（Textarea 内背景） |
| `bg-white/10` | 标签/芯片背景 |
| `bg-white/[0.08]` | hover 态 |
| `border-white/10` | glass-card 边框 |
| `border-white/[0.08]` | 更轻边框 |

**Flutter 实现**：`Colors.white.withOpacity(0.04)` 直接映射。

## 3. 字号梯度（比 InkFrame 更细）

CineFlow 大量用 `text-[Xpx]` 任意字号：
- `text-[9px]` — 辅助提示（mutual exclusion hint）
- `text-[10px]` — 芯片 / 底部控制栏按钮
- `text-xs` = 12px — 类型按钮文字
- `text-sm` = 14px — 正文、textarea
- `text-base` = 16px — 少用
- `text-xl` = 20px — 菜单项大图标内的字符

InkFrame 当前 `InkTypography.body = 14px` 是起点，但**缺小字号** — 需要加 `caption / micro / nano` 变体。

## 4. 按钮变体清单

### 4a. 类型按钮（gradient 彩条）
```tsx
// FloatingToolbar 底部，每种节点类型一个渐变
className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg
           bg-gradient-to-r from-yellow-500 to-orange-500
           text-foreground font-medium
           hover:scale-105 active:scale-95"
```

渐变对应关系：
| 类型 | 渐变 |
|---|---|
| 图片 | from-yellow-500 to-orange-500 |
| 视频 | from-purple-500 to-pink-500 |
| 文本 | from-blue-500 to-cyan-500 |
| 上传 | from-green-500 to-emerald-500 |
| 图片编辑器 | from-green-500 to-teal-500 |
| 文本节点（灰） | from-gray-600 to-gray-700 |

### 4b. 工具按钮（surface 单色）
```tsx
className="px-2.5 py-1.5 rounded-lg bg-cineflow-surface-2
           hover:bg-cineflow-surface-3 text-foreground text-xs"
```

### 4c. 图标按钮（方形 7×7）
```tsx
className="w-7 h-7 rounded-lg bg-cineflow-surface-2 hover:bg-cineflow-surface-3"
```

### 4d. 虚线空槽（"未填"态）
```tsx
className="h-8 px-2.5 rounded-lg border border-dashed border-cineflow-border-default
           text-cineflow-text-tertiary hover:bg-white/5"
```

### 4e. 高亮激活芯片（accent 半透明）
```tsx
className="h-8 px-2.5 rounded-lg border border-cineflow-accent-primary/50
           bg-cineflow-accent-primary/10 text-cineflow-accent-primary"
```

### 4f. 带状态的 popover 触发按钮
```tsx
// 展开时高亮 border，未展开 dashed 暗淡
${isOpen
  ? 'bg-cineflow-surface-3 border-cineflow-border-default text-primary'
  : 'bg-cineflow-surface-3 border-cineflow-border-subtle hover:border-cineflow-border-default'}
```

## 5. 动效 primitive（Framer Motion）

全局套路：
```tsx
whileHover={{ scale: 1.05 }}
whileTap={{ scale: 0.95 }}
transition={{ type: 'spring', damping: 20, stiffness: 300 }}
```

入场：
```tsx
initial={{ y: 100, opacity: 0 }}
animate={{ y: 0, opacity: 1 }}
transition={{ delay: 0.3, type: 'spring', damping: 20 }}
```

出场 popover：
```tsx
initial={{ scale: 0.8, opacity: 0, y: 10 }}
animate={{ scale: 1, opacity: 1, y: 0 }}
exit={{ scale: 0.8, opacity: 0, y: 10 }}
transition={{ duration: 0.15 }}
```

Arrow-hover："菜单项鼠标悬停时右移 4px"
```tsx
whileHover={{ x: 4 }}
```

**Flutter 实现**：
- `AnimatedScale` 做 hover scale
- `flutter_animate` / `AnimatedPositioned` 做 slide in
- Spring 动效用 `SpringSimulation` + `AnimationController`

## 6. Textarea 样式（NodeInlinePanel 核心）

```tsx
className="w-full flex-1 px-3 py-2
           bg-white/[0.04] rounded-lg
           text-sm text-cineflow-text-primary
           placeholder-cineflow-text-tertiary
           resize-none overflow-y-auto scrollbar-thin
           focus:outline-none focus:ring-1 focus:ring-cineflow-border-hover"
```

**关键特征**：
- 不用常规 input border，用 **bg-white/[0.04]** 做区分（比底层面板略亮）
- focus 态加 `ring-1` 细边（ring-offset 默认 0）
- placeholder 用 `text-tertiary` 而不是半透明 primary

## 7. Scrollbar（Chrome/Safari 细化）

```css
.scrollbar-thin::-webkit-scrollbar {
  width: 8px; height: 8px;
}
.scrollbar-thin::-webkit-scrollbar-thumb {
  background: hsl(var(--border-hover)); border-radius: 4px;
}
```

Flutter `Scrollbar` widget 有 `thickness`、`radius`、`thumbColor` — 一比一能做。

## 8. 边（StyledEdge）三态具体数据

**默认态**：
- 渐变：`#F9A8D4 → #C084FC → #818CF8 → #60A5FA → #67E8F9`（粉→紫→蓝→青）
- 主线 stroke-width: **1.5** / opacity **0.75**
- 底辉光 stroke-width: **6** / opacity **0.08** / 2px blur

**强调态**（源/目的节点被选中）：
- 渐变：`#FBBF24 → #F472B6 → #A78BFA → #34D399`（金→粉→紫→青）
- 主线 2.5 / opacity 0.85
- 底辉光 8 / opacity 0.15 / 3px blur + feMerge

**选中态**（边本身被点）：
- 纯色 `#FBBF24`（琥珀黄）
- 主线 3 / opacity 1
- 底辉光 14 / opacity 0.25 / 4px blur

**Flutter 实现**：
- `CustomPainter` + `Path` cubic bezier（`getBezierPath` React Flow 内部公式）
- `Paint.shader = LinearGradient(...).createShader(rect)` 做渐变
- 底辉光用 `Paint..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)` + 低 opacity
- 三态通过条件分支绘三次 path

## 9. NodeCreationMenu 模式

```tsx
// 全屏半透明黑 backdrop + 中央 glass-card
<motion.div className="fixed inset-0 bg-black/20 backdrop-blur-sm z-40" onClick={onClose}/>
<motion.div
  className="fixed z-[650] glass-card p-2 min-w-[240px]"
  style={{ left: x, top: y, transform: 'translate(-50%, -50%)' }}
  initial={{ scale: 0.8, opacity: 0, y: 10 }}
  animate={{ scale: 1, opacity: 1, y: 0 }}
  transition={{ type: 'spring', damping: 20, stiffness: 300 }}
>
  {/* 菜单项列表 */}
</motion.div>
```

**菜单项样式**：
```tsx
<button className="w-full flex items-start gap-3 px-3 py-2.5 rounded-lg
                   hover:bg-cineflow-surface-2 text-left group">
  {/* 彩色渐变 icon 方块 40x40 */}
  <div className={`w-10 h-10 rounded-lg bg-gradient-to-br ${item.color}
                   group-hover:scale-110 transition-transform`}>
    {item.icon}
  </div>
  <div className="flex-1">
    <div className="text-sm font-medium">{label}</div>
    <div className="text-xs text-secondary mt-0.5">{description}</div>
  </div>
  <div className="text-tertiary group-hover:text-secondary">→</div>
</button>
```

## 10. 节点 Shell 基础设施（CineFlow 有 InkFrame 没）

CineFlow 的 `NodeShell` 是一整套模板化系统：
- **Traits**: `useTitleEditing`, `useNodeDelete`, `useNodeClipboard`, `useNodeDuplicate`, `useGenerationStatus`, `useMediaNodeTraits`, `useNodeRegenerate`, `usePromptRegenerate` —— 可插拔能力
- **Overlays**: `GeneratingBorder`, `UneditedBorder`, `PlaygroundBadge`, `InjectedAssetsBadges`, `AssetDragOverlay`, `ErrorOverlay`, `LoadingOverlay`, `PromptChangedOverlay`, `BatchGalleryOverlay`, `UploadProgressBar` —— 状态叠层
- **Resize handles** 4 corner + useNodeResize hook
- **Context menu** (right-click flyout) + `FlyoutMenu` component
- **Spotlight animation** (`node-spotlight-glow`, `-bounce`, `-ring` keyframes)
- **NodeToolbar** / **NodeInfoBar**

这些每个都是**独立 primitive**，InkFrame 里都没有。

## 11. Z-index 层级约定

| z-index | 层 |
|---|---|
| z-[40] | NodeCreationMenu backdrop |
| z-[500] | FloatingToolbar |
| z-[650] | NodeCreationMenu / NodeInlinePanel |
| z-[1000] | Popover backdrop |
| z-[1010] | Popover content |

## 12. 颜色语义补足（InkFrame Sprint 1 漏的）

CineFlow 内部除了 `--accent`, 还有：
```css
--accent-pressed  (212° 38%)  — 按压态
--info            (200° 45%)  — 信息
--cta             (347° 48%)  — 品牌红
--success-fg      (默认 success 的文字色)
```

InkFrame Sprint 1 **已加** `accentPressed / info / cta / ctaHover`。缺的是 `success-fg / warning-fg / danger-fg`（语义色的对比文字色）。

---

## 结论：InkFrame 下一 Sprint 应该是 "Primitives Layer Sprint"

**不要直接造 NodeInlinePanel**，先搭这些原子：

| Primitive | 说明 |
|---|---|
| `InkGlassCard` / `InkGlassPanel` / `InkGlassPill` | 毛玻璃三态容器（BackdropFilter + saturation + 半透明 bg + 薄边） |
| `InkGradientButton` | `from/to` 渐变类型按钮（支持彩条变体） |
| `InkSurfaceButton` | 单色 surface-2 按钮 |
| `InkDashedSlot` | 虚线"空槽"按钮 |
| `InkAccentChip` | accent 半透明高亮芯片 |
| `InkCompactTextField` | `bg-white/[0.04] + ring-1 focus` 风格 textarea |
| `InkPillTag` | 圆形胶囊标签 |
| `InkTypography.micro / nano` | 9px / 10px 字号 |
| `InkMotion.spring` | 预设 Framer-style 弹簧曲线 |

**所有新组件（NodeInlinePanel / FloatingToolbar / NodeCreationMenu / StyledEdge）都基于这些 primitive 组装**，而不是每个都重造一遍视觉样式。

类比：Sprint 1 是色板；**Primitives Sprint 是颜料盒 + 笔刷**；后续 Sprint 才是画画。

---

## Sprint 重新拆解建议（v3）

| # | Sprint | 核心 | 工作量 |
|---|---|---|---|
| 1 | Token 对齐（已做） | InkColors 10 slot + Apple Blue primary | 1 人日 |
| **2 (重做)** | **Primitives Layer** | 上表 9 个原子 + 各自 widget test | 3-4 人日 |
| 3 | **NodeInlinePanel v2** | 基于 primitive 重建 inline panel（Textarea / 底部控制栏 / Camera+Advanced popover） | 2-3 人日 |
| 4 | **FloatingToolbar** | 底部中央 glass-panel 工具条 + 彩条类型按钮 | 1-2 人日 |
| 5 | **StyledEdge** | Bezier 三态 + CustomPainter | 1-2 人日 |
| 6 | **画布交互增强** | Marquee / handle drag / 伙伴边 | 3-5 人日 |
| 6.5 | **Slash / @mention** | 可选 | 2-3 人日 |

**总计 12-20 人日**（含 token 已完成的 1 人日）。

原 Sprint 2（inline panel）保留在 `feature/ui-sprint-2-inline-panel` 分支做参考，但**代码基本要推翻重写**——那条分支的 `InlinePanelController + OverlayEntry + TransformationController` 逻辑层可复用，widget 层（NodeInlinePanel 壳 + 塞 old Inspector）要废。
