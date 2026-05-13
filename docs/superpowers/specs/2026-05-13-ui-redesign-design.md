# InkFrame UI 重构设计文档 — Amber Noir

> **状态**：Draft v1
> **作者**：@KerroKapple + Claude
> **日期**：2026-05-13
> **参考素材**：`D:\Docs\IMG\IF\*.png`（12 张设计稿）
> **承接 issue**：UI/UX 整体重做（无对应 GitHub issue，本文件作为 source of truth）

---

## 1. 范围

### 本轮覆盖（MVP）

| 屏幕 | 参考图 | 当前状态 |
|------|--------|---------|
| **Lock**（API Key 解锁页）| `首页登录.png` | 不存在，新建 |
| **Studio Home**（项目工作台）| `首页.png` | 当前 Hero+列表，**整体重做** |
| **Canvas**（节点画布）| `画布.png` + `任务队列.png` | 当前有 Canvas，**视觉重做** |
| **Frameless 窗口**（去 Windows 白框）| 12 张图均无系统标题栏 | 当前默认带标题栏 |

### 显式排除（下一轮 spec）

- 素材库 / 素材生成 / 智能分镜 / 剧本解析 — 走 ROADMAP epic
- 设置 / 账户设置 / 通知 / 错误页 — 走 spec v2
- Canvas schema 改动（Episode 模型 / 节点类型枚举）— 走独立数据层 spec
- A11y 深化 / i18n 额外语言 — 已有规则继续遵守

---

## 2. 设计语言（Amber Noir）

### 2.1 关键词

电影编辑室 / 分镜师案头 / 暗室文学工具 / 哑光暖黑 + 琥珀金高光 / 反一切毛玻璃 + 蓝紫赛博。

参考品（视觉气质同位）：

- Final Cut Pro X 暗模式
- iA Writer 阅读模式
- Procreate Dreams 工具栏
- Notion 暗模式（但更暖）

### 2.2 Design Tokens（已落地 commit `3234aea`）

色板见 `lib/theme/tokens.dart`，关键值：

| Token | 值 | 用途 |
|------|----|------|
| `surfaceCanvas` | `#0B0908` | 全局最深底 |
| `surface2` | `#15110E` | 卡片底 |
| `surface3` | `#1C1814` | 抬升 / hover |
| `fg1` | `#E8DFD0` | 主文本（暖白）|
| `fg2` | `#B5A89A` | 次文本 |
| `fg3` | `#8A7E70` | 辅助 |
| `accent` | `#C9A85B` | 琥珀金细线 / 描边 / 高光 |
| `cta` | `#E3A648` | 实色按钮（Unlock / New Project）|
| `danger` | `#C8523A` | 错误 |
| `warning` | `#D88B3A` | 警告 |
| `success` | `#5C8A4E` | 成功 |
| `info` | `#4B7A92` | 信息 |
| `border` | `#2A2522` | 默认 1px 描边 |

### 2.3 Typography

| 字体 | 用途 | 来源 |
|------|------|------|
| **Cormorant Garamond** (Light/Regular/Italic) | logo / 大标题 / 项目名 | bundle to assets, 离线可用 |
| **Inter** (现有 typography.dart 默认) | UI 正文 / 控件 / 表单 | 系统 fallback `sans-serif` |
| **JetBrains Mono** | code-like 标签（ID / 版本 / 行号）| bundle to assets |

新增 `InkTypography` 字段：

- `display` → Cormorant Garamond Light 36-48pt（Lock + Studio Hero）
- `headline` → Cormorant Garamond Regular 22pt（项目卡标题）
- `caption` → JetBrains Mono 11pt（ID / 时间戳 / 版本号）

### 2.4 组件规范

#### 2.4.1 新增 `InkNoirCard`

替换 `InkGlassCard`。规格：

- 背景：`surface2` 实色（**不**毛玻璃）
- 边框：1px `border` 实线（hover 时变 `accent`，过渡 120ms）
- 圆角：`InkRadius.lg`（12px）
- 阴影：无（参考图全部哑光，不发光、不投影）

#### 2.4.2 新增 `InkAmberButton`（CTA 实色金按钮）

参考 Lock 屏 Unlock + Studio Home "New Project"：

- 背景：`cta` 实色
- 文字：`surfaceCanvas` 深色
- 圆角：`InkRadius.md`（8px）
- hover：背景 `ctaHover`
- 高度：44px（standard CTA）

#### 2.4.3 新增 `InkGhostButton`（次按钮 / hover 才出描边）

用于工具栏 / 顶部 chrome：

- 默认无背景无边
- hover：1px `border` + bg `surface3`
- 文字：`fg2`

#### 2.4.4 废弃组件

`InkGlassCard` / `InkGradientButton` / `InkPillTag`（视觉与目标不符）— 标记 `@Deprecated`，本轮替换所有调用点，下个 commit 物理删除。

---

## 3. 屏幕设计

### 3.1 Lock screen（`首页登录.png`）

**布局**（1536×984 viewport）：

```
┌──────────────────────────────────────────────────────────┐
│                                            [ 中 / EN ]    │  ← 右上语言切换（IkkGhostButton）
│                                                          │
│  (背景：大 "I" 衬线字 50% 透明，左下角溢出)              │
│                                                          │
│                                                          │
│                     Ink/Frame                            │  ← Cormorant Garamond Light 56pt
│                                                          │     "/" 是 accent 色
│                A DESK FOR STORYBOARDERS                  │  ← JetBrains Mono 11pt letterSpacing 4
│                                                          │
│           ┌────────────────────────────────────┐         │
│           │  Paste provider key...        [👁] │         │  ← 下划线输入框
│           └────────────────────────────────────┘         │     border-bottom 1px border
│                                                          │     focus 时 accent 1px
│           Get your API key from your provider           │
│           dashboard.                                     │  ← fg3 caption
│           We never store your key on our servers.       │
│                                                          │
│           ┌────────────────────────────────────┐         │
│           │            Unlock                  │         │  ← InkAmberButton h=56
│           └────────────────────────────────────┘         │
│                                                          │
│  v0.14.2 -- 3f8c91a                                      │  ← 左下版本 caption mono
└──────────────────────────────────────────────────────────┘
```

**关键交互**：

- 输入框走 `InkSecurePasswordField`（密码默认 mask；右侧眼图标切显示）
- Unlock 提交 → 调 `KeyValidatable.validateApiKey` → 成功后 `SecureStorageService.store` + 路由跳 Studio Home
- 验证失败：输入框下方红色 caption "Key invalid or network error. Try again."
- 中英切换写入 `localePreferenceProvider`，立即生效

**i18n keys 新增**：

- `lockTagline` → "A DESK FOR STORYBOARDERS" / "为分镜师而生的工作台"
- `lockKeyPlaceholder` → "Paste provider key..." / "粘贴 Provider Key..."
- `lockKeyHelp` → 两行说明
- `lockUnlock` → "Unlock" / "解锁"
- `lockKeyInvalid` → 错误提示

### 3.2 Studio Home（`首页.png`）

**布局**：

```
┌──────────────────────────────────────────────────────────────────────┐
│  Ink/Frame                Kerro Studio › Projects › All     [⌘K] [@] │  ← Top chrome 56px
├──────────────┬───────────────────────────────────────────────────────┤
│ LIBRARY      │  Recent Projects                          [▦] [≡]    │
│              │                                                       │
│ 📁 Kerro     │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐       │
│   Studio  12 │  │剧照缩略│ │剧照缩略│ │剧照缩略│ │剧照缩略│       │
│ ▼ Projects 8 │  │  16:10 │ │  16:10 │ │  16:10 │ │  16:10 │       │
│   ↳ Nocturne │  ├────────┤ ├────────┤ ├────────┤ ├────────┤       │
│     EP01     │  │Nocturne│ │Last Ha…│ │Paper R…│ │Eclipse │       │
│   ▶ EP02 ●   │  │EP02·05.│ │EP01·05.│ │EP01·05.│ │EP04·05.│       │
│     EP03     │  │  · 27  │ │  · 14  │ │  · 09  │ │  · 33  │       │
│   ▶ Last H 2 │  └────────┘ └────────┘ └────────┘ └────────┘       │
│   ▶ Paper  1 │                                                       │
│   ▶ Eclipse4 │  (第二行同结构 4 卡)                                 │
│   ▶ Ashes  3 │                                                       │
│   ▶ Afterl 2 │                                                       │
│   ▶ Fragm  1 │                                                       │
│              │                                                       │
│              │                                                       │
│ ARCHIVE      │                                                       │
│ 🗃 Archived  7│                          ┌──────────────────────┐    │
│              │                          │  +   New Project     │    │  ← InkAmberButton 右下定位
│ ⚙ 📦 👤 🗑    │                          └──────────────────────┘    │
└──────────────┴───────────────────────────────────────────────────────┘
```

**组件树**：

```
StudioHomeScreen
├── TopChrome (logo + breadcrumb + ⌘K + avatar)
├── Row
│   ├── LibrarySidebar (固定宽 280px)
│   │   ├── SectionHeader "LIBRARY"
│   │   ├── TreeNodeStudio (展开 Projects)
│   │   ├── 项目列表 (可展开成 episodes)
│   │   ├── SectionHeader "ARCHIVE"
│   │   └── BottomActionBar (设置/归档/账户/垃圾桶 4 icon)
│   └── Expanded
│       └── Stack
│           ├── ProjectGrid (4 列, 响应式: <1280 -> 3 列)
│           └── Positioned bottom-right: InkAmberButton "New Project"
```

**新增 i18n keys**：

- `studioRecentProjects` → "Recent Projects" / "最近项目"
- `studioNewProject` → "New Project" / "新建项目"
- `studioLibrary` / `studioArchive` 等

**新增 Riverpod providers**：

- `currentStudioProvider` → 当前选中的 Studio 名称（默认 "Kerro Studio"）
- `selectedProjectIdProvider` → 左侧树选中项
- `archivedProjectsProvider` → 归档项目列表（按 `archived_at IS NOT NULL` 过滤）

### 3.3 Canvas（`画布.png` + `任务队列.png`）

**布局**：

```
┌──────────────────────────────────────────────────────────────────────┐
│ Ink/Frame   Project › Nocturne › Episode 02 › Canvas     [⌘K][▶][@] │  ← Top chrome
├──┬───────────────────────────────────────────────────────┬───────────┤
│⏶│       [mini-map] 87% [-/+] [🔒] [60 FPS]               │ Wide Shot │
│⊕│                                                        │ Camera Nd │
│⊞│  (画布主区, dotted grid 背景, surfaceCanvas)           │ ID cam_002│
│↗│                                                        │           │
│◯│  ┌─Character──┐   ┌─Scene──────┐   ┌─Camera──────┐   │ Transform │
│T│  │ Elara     ★│──>│Harbor Docks│──>│ Wide Shot   │──>│ Pos x/y   │
│◌│  │ [thumb]    │   │ [thumb]    │   │ [thumb]     │   │ Rotation  │
│□│  │ chr_0042  │   │ scn_0107   │   │ cam_0021    │   │ Scale     │
│ │  └────────────┘   └────────────┘   └─────────────┘   │ Pivot     │
│ │                                                        │           │
│ │  ┌─Prop───────┐   ┌─Shot───────┐   ┌─Image Gen──┐   │ Camera ⌄  │
│ │  │Pocket Watch│──>│ CU Watch   │──>│Watch Close. │   │ Lens 28mm │
│ │  │ [thumb]    │   │ [thumb]    │   │ [thumb]     │   │ Focal 28  │
│ │  │ prop_0066  │   │ shot_0154  │   │ job_2231    │   │ Aperture  │
│ │  └────────────┘   └────────────┘   └─────────────┘   │ ...       │
│ │                                                        ├───────────┤
│↶│                                                        │ Render Q  │
│↷│                                                        │ 3 jobs    │
│⤢│                                                        │ Watch C…  │
│⊹│                                                        │ ████ 45%  │
│ │                                                        │ Harbor D…│
│⏷│ Pan [Space] Zoom [⌘+/-] AddNode [A] Connect [C] ...   │ ▌  18%   │
└──┴───────────────────────────────────────────────────────┴───────────┘
   ↑                                                        ↑
   左 toolbar 56px                                  右 Inspector 320px
```

**节点卡设计**：

- 卡片背景：`surface2`
- 1px 描边 `border`
- 顶部 4px 色条（类型色，本轮 hardcode 一个 map：Character=amber, Scene=blue-info, Camera=warning, Prop=danger, Shot=neutral border, ImageGen=success）
- 标题：Cormorant Garamond Regular 14pt
- 缩略图：16:9 占位（无图时 `surface3` 实色）
- ID + RES 行：JetBrains Mono 10pt fg3
- 选中态：accent 1px 描边

**Inspector**：

- 宽 320px 固定，可折叠（点 × 收起，展开按钮停在 toolbar）
- 节标题：Cormorant Garamond Regular 16pt
- 字段行：左 label fg3 / 右 value fg1 mono
- 折叠组：▼ / ▶ 切换

**Render Queue**：

- Inspector 下方折叠面板（与上方 Inspector 联动 1:1 占比可调拽，先 fix 2/3 + 1/3）
- 列表项：缩略图 32px + 标题 + provider + 进度条（accent 色填充）
- 队列条目数据源：`jobQueueServiceProvider.activeJobsStream`

**i18n keys 新增**（节选）：

- `canvasInspectorTransform` / `canvasInspectorCamera` / `canvasInspectorNotes` 等
- `canvasRenderQueue` / `canvasRenderQueueJobs(count)`

### 3.4 Frameless 窗口

**依赖**：`window_manager: ^0.4.x`（pubspec 新增）

**配置**：

- 启动时 hide 系统标题栏 + 自绘 chrome
- chrome 高度 56px（即 Top chrome 那一栏，同时承担拖拽）
- 右上 [— ▢ ✕] 三按钮（自绘，hover 时 surface3）
- macOS：traffic lights 自动隐藏，使用三按钮一致风格
- 双击 chrome 区域 maximize / restore

**实现位置**：

- 新建 `lib/theme/components/ink_window_chrome.dart`
- 在 `lib/main.dart` 启动时 `await windowManager.ensureInitialized()` + `windowManager.setTitleBarStyle(TitleBarStyle.hidden)`
- 替换 `MaterialApp` 外壳为带 chrome 的 layout

---

## 4. 数据流 / DI

### 4.1 新 providers

| Provider | scope | 来源 |
|----------|-------|------|
| `localePreferenceProvider` | keepAlive | SettingsService（已存在）|
| `apiKeyUnlockedProvider` | keepAlive | 检查 SecureStorageService 是否有任一 provider key |
| `currentStudioProvider` | keepAlive | hardcode "Kerro Studio"（v1）|
| `selectedProjectIdProvider` | autoDispose | UI 状态 |
| `studioProjectsProvider` | autoDispose | repackage `workspaceProjectsProvider` |

### 4.2 路由

```
GoRoute /lock              → LockScreen
GoRoute /studio            → StudioHomeScreen
GoRoute /canvas/:canvasId  → CanvasScreen
```

启动时 `redirect`：

- 未解锁 → /lock
- 已解锁 + 无 currentCanvasId → /studio
- 已解锁 + 有 currentCanvasId → /canvas/:id

---

## 5. 错误处理

- API key 验证失败：Lock 屏内联红字提示，不弹 Toast（首屏不应有 Toast 干扰）
- 项目加载失败：Studio Home 中央显示 `InkErrorPanel`（参考 `错误类型.png` 卡片，本轮简化为单卡）
- Canvas 失败：fallback 到 Studio Home + Toast 报错

---

## 6. 测试策略

- Widget tests：每个新屏一个 `pumpWidget` smoke test（渲染不抛 + 关键元素 finder.byType）
- Tokens snapshot：`tokens_test.dart` 已含 exact-value 断言（commit `3234aea`）
- 黄金（golden）测试：本轮**不**加 golden（视觉迭代期，pixel diff 会噪）
- i18n 一致性：现有 `check-i18n-coverage.sh` hook 保护，新增 keys 必须 en/zh 同步

---

## 7. 实施顺序（粗排，详细排期走 writing-plans）

1. **基建** — `pubspec` 加 `window_manager` + Cormorant Garamond / JetBrains Mono 字体文件
2. **Typography 升级** — `typography.dart` 加 display/headline/caption + fontFamily
3. **新增 primitives** — `InkNoirCard` / `InkAmberButton` / `InkGhostButton`
4. **Lock screen** — 最小可独立验收
5. **Frameless 窗口 chrome** — main.dart + ink_window_chrome.dart
6. **Studio Home 重写** — workspace_home_screen.dart 完全重写
7. **Canvas 视觉重写** — 节点卡 + Inspector + Render Queue
8. **废弃旧 primitives** — 删 `InkGlassCard` / `InkGradientButton` / `InkPillTag`
9. **i18n keys 全量补完** — 双语
10. **CI 全绿 + 发 PR**

---

## 8. 验收标准

- [ ] Lock 屏第一帧渲染与 `首页登录.png` 偏差 < 5%（视觉评审）
- [ ] Studio Home 与 `首页.png` 偏差 < 10%（左树 / 卡网格 / FAB 全到位）
- [ ] Canvas 节点卡 + Inspector + Render Queue 与 `画布.png` + `任务队列.png` 视觉一致
- [ ] Windows + macOS 都跑通 frameless 窗口
- [ ] 旧的 `InkGlassCard` / `InkGradientButton` / `InkPillTag` 在 lib/ 下零引用
- [ ] `flutter analyze` clean, `flutter test` 全过
- [ ] ARB 双语覆盖 100%

---

## 9. 未决 / 后续

- A11y：本轮保持现有 `Semantics` 包装，不深化（专题独立 spec）
- 多 Studio：本轮 hardcode 单 Studio，多 Studio 切换走 v2
- Canvas 数据模型：Episode / 节点类型 enum / DB migration 全部不在本轮（独立 spec）
- 设置 / 通知 / 错误页 / 素材库 / 生成 / 分镜 / 脚本 → spec v2

