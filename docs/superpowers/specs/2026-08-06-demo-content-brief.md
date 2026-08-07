# DEMO-1 演示内容执行说明书（交付 Codex 执行）

> **这是什么**：把「示例项目」从「一个预填 prompt 的空节点」升级为「打开即见的完整分镜成片链」。
> 分两部分：**A 出图任务**（Codex 内置出图，22 张，可独立完成）、**B 集成任务**（工程侧接线，
> 依赖 A 的产物）。两部分可分两个 PR，也可合一。
> **写于** 2026-08-06 · **状态** 待执行 · **前置** 无（不依赖 API key、不依赖签名）

---

## 0. 执行前必读：当前状态与一期范围

**状态（2026-08-07 更新）**：showcase 页 + 两张随包图已随 **PR #214（`d2afb2d`）合入 main**，
工作区干净。本节初版写的「main 上有未提交改动、先切分支挪走」那段指令**已作废**，勿再执行。

`assets/showcase/` 的两张图（`ink-wash-mountains-square.jpg` 1024²/246KB、
`ink-wash-storyboard-wide.jpg` 1536×864/297KB）现由内置示例页在用，**原位不动**；
它们同时是模板一的画风基准，见 §A.1「已有资产的处置」。

**一期范围（当前要执行的）**：只做 **模板一 `homecoming` 的 8 张图**（§A.3）+ 其集成（Part B）。
模板二 `echo-station`、模板三 `morning-tram` 的 prompt 已写全并保留在本文档 §A.4 / §A.5，
**二期再出**——一次性 +4.5MB 进安装包不划算，且一期若要改规格只返工 8 张。

**投喂 Codex 的指令块见 §A.0**（一期只需读 §A.0 + §A.3 两节）。

> ⚠️ 另请注意：这两张图**不能**用来给 BOARD 的 MOD-1「真 key 冒烟」验收项打勾。
> 那一项要的是「InkFrame 发出的准确请求体被 OpenAI API 接受」的证据（HTTP 200 +
> `data[0].b64_json` 非空），Codex 内置出图拿不到，该项保持未勾、等有 API key 的环境再收。

---

# Part A — 出图任务

## A.0 一期投喂指令（给 Codex 的完整任务书）

> 一期只做模板一。Codex 执行时只需要本节 + §A.3 的 8 条 prompt，其余章节可不读。

### 任务

用内置出图能力生成 **8 张图**：6 张分镜 + 2 张角色参考。prompt 在 **§A.3**，逐条原样复制，
一条一张，不改写、不合并、不精简。

### 产物落点（严格照此路径与命名，大小写敏感）

```
assets/samples/homecoming/
├── shot-01.jpg
├── shot-02.jpg
├── shot-03.jpg
├── shot-04.jpg
├── shot-05.jpg
├── shot-06.jpg
├── character-portrait.jpg     # §A.3「角色参考图」第一条（半身）
└── character-full.jpg         # §A.3「角色参考图」第二条（全身）
```

`assets/samples/` 目录当前**不存在**，需新建。文件名与 §A.3 的小标题一一对应：
`shot-0N.jpg` 对应 §A.3「出图 prompt」里的 **shot-0N**。

### 规格

| 项 | 分镜图 `shot-0N.jpg` | 角色参考图 `character-*.jpg` |
|---|---|---|
| 像素尺寸 | **1536 × 864**（严格，验收会逐张读像素） | **1024 × 1024**（严格） |
| 格式 | JPEG | JPEG |
| 单张体积 | **≤ 220 KB** | **≤ 160 KB** |

**体积超了就降 JPEG 质量重存（从 ~78 往下调），绝不改像素尺寸。** 尺寸不对 = 验收直接打回。
8 张合计应 ≈ 1.6–1.8 MB。

### 这些图会出现在哪里（决定构图取向，务必读）

**不是给内置示例页用的**——那页用的是 `assets/showcase/` 的两张，本次不动它。

这 8 张的去处是 **「创建示例项目」**：用户点「创建示例项目」后，程序会把这些字节写进用户的
项目目录，于是画布上直接呈现一条完整分镜链——

- 6 张分镜图 → 6 个 **image result 节点**的成品图，挂在对应 shot 节点下方
- 2 张角色图 → 项目角色**「蓑衣旅人」**的参考图，在角色区展示
- 6 张分镜图同时进**画廊**，可筛选、可「存为角色」

因此每张图要同时经得起**两种观看尺度**：

1. **画布节点卡缩略图（约 260 px 宽）** —— 主体缩到这个尺寸仍要一眼可辨。避免「整幅都是细密
   皴擦纹理、主体淹没其中」；旅人身上那抹红要在缩略图上仍然看得见。
2. **画廊大图预览（全屏）** —— 细节要经得起放大。

配套两条硬要求：

- **主体不要贴边**：节点卡按 16:9 等比显示、画廊可能有轻微裁切，四周留出安全边距
- **不要在画面里写字**：任何文字（标题、字幕、水印、签名、伪汉字）都不要出现——它们在缩略图上
  变成噪点，且我们无法对其做 i18n

### 不要做的事（越界会被打回）

- ❌ **不要动 git**：不建分支、不 `add`、不 `commit`、不 `push`。图由我方随 Part B 集成 PR
  一起提交——单独的资产 PR 既没进 `pubspec.yaml` 也没有测试引用，是死重。
- ❌ **不要改任何代码**：`.dart` / `pubspec.yaml` / ARB / 测试一律不碰。一期出图任务的产出
  **只有 8 个 jpg 文件**，`git status` 应当只多出 `assets/samples/homecoming/` 一个未跟踪目录。
- ❌ **不要动 `assets/showcase/`** 的两张已发布资产。
- ❌ **不要把图放到 `assets/samples/homecoming/` 以外的任何位置**（含临时目录、桌面、下载夹）。
- ❌ **不要顺手把模板二/三也生成了**（§A.4 / §A.5 是二期的，现在出了也用不上，白烧）。
- ❌ **不要简写 prompt**。跨请求没有上下文，写 `the same traveler` 必然画出另一个人；
  斗笠 / 蓑衣 / **红围巾** / 竹杖行囊这几个锚点词一个都不能删。

### 允许的自由裁量

- 单张跑偏就**重抽那一张**，不用重跑整组。水墨风对细节宽容，「一眼看得出是同一个人」即达标。
- 出图模型若因内容策略拒绝某条 prompt：把**动作描述**改温和些重试，**角色描述保持原样**。
- 同一模板尽量在一次会话里连续生成，中途不改风格串措辞。

### 交付回报格式（照抄这张表填，我据此验收）

| 文件 | 像素尺寸 | 字节数 | 重抽次数 |
|---|---|---|---|
| shot-01.jpg | | | |
| …（8 行填满） | | | |

若你的环境读不到像素尺寸，只填字节数即可，尺寸由我方逐张解码核验。另外请一并说明：

1. 有没有哪条 prompt 被模型拒绝过、你如何改的（原话贴出来）
2. 有没有哪张你自己觉得角色一致性存疑

## A.1 交付总表

> **本节是全量口径（三模板 22 张）。一期只出下表第一行的 8 张**——执行口径以 §A.0 为准。

三个故事模板，每个 = N 张分镜图 + 2 张角色参考图。

| 模板 | 目录名 | 画风 | 分镜 | 角色图 | 小计 |
|---|---|---|---|---|---|
| 归乡 Homecoming | `homecoming` | 传统水墨 | 6 | 2 | 8 |
| 回声站 Echo Station | `echo-station` | 复古未来科幻 | 5 | 2 | 7 |
| 早班电车 Morning Tram | `morning-tram` | 柔和水彩 | 5 | 2 | 7 |
| | | | **16** | **6** | **22** |

**技术规格（全模板统一）**

| 项 | 分镜图 | 角色参考图 |
|---|---|---|
| 尺寸 | **1536 × 864**（16:9） | **1024 × 1024**（1:1） |
| 格式 | JPEG，质量 ~78 | JPEG，质量 ~78 |
| 单张体积上限 | **≤ 220 KB** | **≤ 160 KB** |
| 命名 | `shot-01.jpg` … `shot-06.jpg` | `character-portrait.jpg` / `character-full.jpg` |

超出体积上限就降质量重存（别改尺寸）。22 张合计应 ≈ 4.5MB。

**产物存放**

```
assets/samples/
├── homecoming/
│   ├── shot-01.jpg … shot-06.jpg
│   ├── character-portrait.jpg
│   └── character-full.jpg
├── echo-station/
│   ├── shot-01.jpg … shot-05.jpg
│   ├── character-portrait.jpg      # 工程师
│   └── character-companion.jpg     # 机器猫
└── morning-tram/
    ├── shot-01.jpg … shot-05.jpg
    ├── character-portrait.jpg      # 少女
    └── character-companion.jpg     # 橘猫
```

**已有资产的处置**：`assets/showcase/` 那两张保持原位不动（showcase 页在用）。
本次新出的 22 张一律进 `assets/samples/`，两套资产互不干扰。

## A.2 出图方法论（决定成败，务必照做）

1. **每条 prompt 都是自包含的**。下面每一条都已经写成「风格串 + 角色完整外观 + 镜头内容 +
   构图」的完整句子，**直接复制单独一条就能出图**。不要因为「上一张已经画过这个角色」就简写成
   `the same traveler`——跨请求没有上下文，简写必然画出另一个人。
2. **角色一致性靠硬锚点**，不靠形容词。每个角色的描述里都埋了 2-3 个不会被模型忽略的特征
   （唯一亮色、独特道具、剪影轮廓）。这些词一个都不能删。
3. **同一模板尽量一次会话连续生成**，中途不要改风格串措辞。
4. **可以重抽**。某张角色跑偏了就重生成那一张，不用重跑整组。水墨/水彩风本身对细节宽容，
   不追求像素级一致——「一眼看得出是同一个人」即达标。
5. 出图模型若拒绝某条 prompt（内容策略），把该镜的动作描述改温和些重试，**不要**改角色描述。

---

## A.3 模板一「归乡 / Homecoming」

- **一句话**：旅人翻山越岭，夜归故乡，从破晓山径走到炉边热茶。
- **演示什么**：分镜链（Shot 节点 → narrative 边）、角色一致性、风格泳道。
- **风格串**（下面每条 prompt 已内嵌，此处单列供泳道 `laneStylePrompt` 使用）：

```
traditional Chinese ink wash painting, muted sepia and slate gray tones, a single red accent, soft mist, cinematic composition
```

- **角色硬锚点**：斗笠 + 蓑衣 + **红围巾**（唯一亮色）+ 竹杖行囊。

### 角色参考图（1024 × 1024）

**`character-portrait.jpg`**
```
Traditional Chinese ink wash painting, muted sepia and slate gray tones, a single red accent, soft mist. Character reference portrait, upper body, of a weathered lone traveler: wide conical bamboo hat, woven straw raincoat over dark robes, a bright red scarf wrapped at the neck, weathered face with a short gray beard. Plain pale rice-paper background, no scenery. Cinematic composition.
```

**`character-full.jpg`**
```
Traditional Chinese ink wash painting, muted sepia and slate gray tones, a single red accent, soft mist. Character reference sheet, full body standing pose, of a weathered lone traveler: wide conical bamboo hat, woven straw raincoat over dark robes, a bright red scarf, carrying a cloth bundle tied to a bamboo staff over one shoulder, worn cloth boots. Plain pale rice-paper background, no scenery.
```

### 分镜（1536 × 864）

| # | 镜头 EN / ZH | 备注 EN（进 ARB，也是生成输入） | 备注 ZH |
|---|---|---|---|
| 1 | Dawn Ridge / 山径破晓 | Extreme wide establishing shot. The traveler is a tiny silhouette on the ridge line at first light. | 大远景定场：晨光初现，旅人只是山脊线上的一个小小剪影。 |
| 2 | The Rope Bridge / 渡索桥 | Medium shot. Crossing a rope bridge over a misty gorge, wind pulling the red scarf sideways. | 中景：过峡谷索桥，风把红围巾扯向一侧。 |
| 3 | Tea Shed / 茶棚避雨 | Close shot. Resting at a roadside tea shed as the rain starts, hat set aside, steam rising. | 近景：路边茶棚歇脚，雨刚落，斗笠搁在一旁，热气升腾。 |
| 4 | Bamboo at Dusk / 竹林夜行 | High angle shot. Descending through rain-soaked bamboo, village lights glowing far below. | 俯瞰：雨夜穿过竹林下山，山谷里村灯已亮。 |
| 5 | The Gate / 柴门灯火 | The emotional peak. Arriving at an old courtyard gate at night, lantern light spilling out, a dog running to greet him. | 高潮：夜抵老宅柴门，灯笼光泻出门缝，家犬奔出相迎。 |
| 6 | By the Hearth / 炉边 | Closing shot. Sharing tea by the hearth fire, raincoat and hat hanging by the door. | 收束：炉火边共饮热茶，蓑衣斗笠挂在门后。 |

**出图 prompt（逐条复制）**

**shot-01.jpg**
```
Traditional Chinese ink wash painting, muted sepia and slate gray tones, a single red accent, soft mist, cinematic composition. Extreme wide establishing shot at dawn: layered mountain ridges receding into pale mist, and on the far ridge line a tiny distant silhouette of a lone traveler wearing a wide conical bamboo hat and a woven straw raincoat, a bright red scarf the only spot of color, a bamboo staff with a cloth bundle over one shoulder. First light spilling across the valleys. Vast negative space, horizontal 16:9 framing.
```

**shot-02.jpg**
```
Traditional Chinese ink wash painting, muted sepia and slate gray tones, a single red accent, soft mist, cinematic composition. Medium shot: a weathered lone traveler wearing a wide conical bamboo hat and a woven straw raincoat, a bright red scarf pulled sideways by the wind, a bamboo staff with a cloth bundle over one shoulder, crossing a swaying rope bridge above a mist-filled gorge. Gnarled pines cling to the cliff walls on both sides. Horizontal 16:9 framing.
```

**shot-03.jpg**
```
Traditional Chinese ink wash painting, muted sepia and slate gray tones, a single red accent, soft mist, cinematic composition. Close shot inside a small roadside tea shed: a weathered lone traveler in a woven straw raincoat, a bright red scarf at his neck, his wide conical bamboo hat set aside on the bench, both hands around a steaming bowl of tea. First rain streaking off the thatched eaves behind him, warm steam catching the light. Horizontal 16:9 framing.
```

**shot-04.jpg**
```
Traditional Chinese ink wash painting, muted sepia and slate gray tones, a single red accent, soft mist, cinematic composition. High angle shot looking down a mountain path: a weathered lone traveler wearing a wide conical bamboo hat and a woven straw raincoat, a bright red scarf visible from above, a bamboo staff with a cloth bundle, descending through a rain-soaked bamboo forest at dusk. Far below in the valley, the warm scattered lights of a village. Horizontal 16:9 framing.
```

**shot-05.jpg**
```
Traditional Chinese ink wash painting, muted sepia and slate gray tones, a single red accent, soft mist, cinematic composition. Night scene at an old courtyard gate: a weathered lone traveler wearing a wide conical bamboo hat and a woven straw raincoat, a bright red scarf at his neck, a bamboo staff with a cloth bundle, standing as the wooden gate opens and warm lantern light spills across the wet stone threshold. A small dog runs out toward him. Horizontal 16:9 framing.
```

**shot-06.jpg**
```
Traditional Chinese ink wash painting, muted sepia and slate gray tones, a single red accent, soft mist, cinematic composition. Warm interior night scene: a weathered traveler with a short gray beard, his bright red scarf now draped over the back of a wooden chair, sitting by a low hearth fire sharing tea from a clay pot. His woven straw raincoat and wide conical bamboo hat hang on a peg by the door. Firelight is the only light source. Horizontal 16:9 framing.
```

---

## A.4 模板二「回声站 / Echo Station」

- **一句话**：深空轨道站的独守工程师收到未知信号，与机器猫一起把它解析成一幅星图。
- **演示什么**：与模板一形成画风反差（水墨 vs 科幻），证明风格泳道的差异化价值。
- **风格串**：

```
retro-futurist science fiction illustration, teal and amber color palette, subtle film grain, wide cinematic framing
```

- **角色硬锚点**：工程师=**琥珀色肩章**的青蓝连体服 + 银灰短发；伙伴=**黄铜机器猫，单只琥珀色光学镜头眼**。

### 角色参考图（1024 × 1024）

**`character-portrait.jpg`**（工程师）
```
Retro-futurist science fiction illustration, teal and amber color palette, subtle film grain. Character reference portrait, upper body, of a lone station engineer: short-cropped silver hair, a teal jumpsuit with a glowing amber shoulder patch, a utility harness across the chest, calm tired eyes. Plain dark background, no scenery.
```

**`character-companion.jpg`**（机器猫）
```
Retro-futurist science fiction illustration, teal and amber color palette, subtle film grain. Character reference, full body side view, of a small brass-plated robot cat: riveted metal panels, a single round amber optical lens for an eye, a segmented cable tail, soft glowing seams along its flanks. Plain dark background, no scenery.
```

### 分镜（1536 × 864）

| # | 镜头 EN / ZH | 备注 EN | 备注 ZH |
|---|---|---|---|
| 1 | Orbital Watch / 轨道守望 | Wide establishing shot. The lonely station drifts against a planet's night side. | 大远景定场：轨道站孤悬于行星夜面之上。 |
| 2 | Weightless Morning / 失重清晨 | Interior medium shot. The engineer drifts through the cabin, the robot cat tumbling alongside. | 舱内中景：工程师在失重中飘过舱室，机器猫翻滚跟随。 |
| 3 | The Signal / 信号 | Close shot. A waveform blooms across the console; the engineer freezes mid-motion. | 近景：控制台上波形骤然绽开，工程师动作定格。 |
| 4 | Aligning the Dish / 校准天线 | Exterior wide shot. EVA outside the hull, turning the dish toward deep space. | 舱外远景：太空行走，把天线转向深空。 |
| 5 | Star Chart / 星图 | Closing shot. The decoded signal unfolds into a projected star map filling the cabin. | 收束：解出的信号在舱内展开成一幅投影星图。 |

**出图 prompt（逐条复制）**

**shot-01.jpg**
```
Retro-futurist science fiction illustration, teal and amber color palette, subtle film grain, wide cinematic framing. Extreme wide establishing shot: a small solitary orbital station with rotating rings and a large dish antenna, drifting above the night side of a blue-gray planet, thin amber city lights scattered on the dark surface far below, a faint band of stars behind. No figures visible. Horizontal 16:9 framing.
```

**shot-02.jpg**
```
Retro-futurist science fiction illustration, teal and amber color palette, subtle film grain, wide cinematic framing. Interior medium shot inside a cramped orbital station cabin: a station engineer with short-cropped silver hair, a teal jumpsuit with a glowing amber shoulder patch and a utility harness, drifting weightless past banks of analog instruments; beside her tumbles a small brass-plated robot cat with a single round amber optical lens for an eye and a segmented cable tail. Floating cables and a drifting coffee bulb. Horizontal 16:9 framing.
```

**shot-03.jpg**
```
Retro-futurist science fiction illustration, teal and amber color palette, subtle film grain, wide cinematic framing. Close shot at a control console: a station engineer with short-cropped silver hair and a teal jumpsuit with a glowing amber shoulder patch, frozen mid-motion, face lit from below by an unfamiliar waveform blooming in amber across a curved CRT display. The brass-plated robot cat with a single amber lens eye perches on the console edge, staring at the screen. Horizontal 16:9 framing.
```

**shot-04.jpg**
```
Retro-futurist science fiction illustration, teal and amber color palette, subtle film grain, wide cinematic framing. Exterior wide shot in space: a station engineer in a bulky teal EVA suit with a glowing amber shoulder patch, tethered to the hull, gripping the frame of a large dish antenna and turning it toward deep space. The station's rings and the curve of the planet fill the lower frame; stars scatter above. Horizontal 16:9 framing.
```

**shot-05.jpg**
```
Retro-futurist science fiction illustration, teal and amber color palette, subtle film grain, wide cinematic framing. Interior wide shot: the cabin filled with a translucent amber holographic star map unfolding in mid-air, constellations and orbital paths drawn in glowing lines. A station engineer with short-cropped silver hair and a teal jumpsuit with an amber shoulder patch floats within it, one hand raised into the projection; the small brass-plated robot cat with a single amber lens eye drifts nearby, lit by the light. Horizontal 16:9 framing.
```

---

## A.5 模板三「早班电车 / Morning Tram」

- **一句话**：面包店学徒少女赶早班电车去开店，路上撞见城市苏醒的一段温暖日常。
- **演示什么**：InkFrame 不只做史诗感，日常温暖题材同样成立。
- **风格串**：

```
soft watercolor anime style, warm morning light, gentle pastel palette, delicate line work
```

- **角色硬锚点**：少女=**黄发带** + 沾面粉的围裙 + 深色麻花辫；伙伴=**胸口有白斑的橘猫**。

### 角色参考图（1024 × 1024）

**`character-portrait.jpg`**（少女）
```
Soft watercolor anime style, warm morning light, gentle pastel palette, delicate line work. Character reference portrait, upper body, of a young baker's apprentice girl: dark hair in a single braid tied with a yellow ribbon, a flour-dusted white apron over a soft blue dress, rolled-up sleeves, a bright cheerful expression. Plain cream-colored background, no scenery.
```

**`character-companion.jpg`**（橘猫）
```
Soft watercolor anime style, warm morning light, gentle pastel palette, delicate line work. Character reference, full body, of a plump orange tabby cat with a distinct white patch on its chest and white paws, sitting upright with its tail curled around its feet. Plain cream-colored background, no scenery.
```

### 分镜（1536 × 864）

| # | 镜头 EN / ZH | 备注 EN | 备注 ZH |
|---|---|---|---|
| 1 | City Waking / 城市苏醒 | Wide establishing shot. Rooftops and tram wires at first light. | 大远景定场：晨光里的老城屋顶与电车线。 |
| 2 | Flour and Fur / 面粉与猫 | Interior medium shot. Kneading dough at dawn, the cat watching from the window sill. | 店内中景：天刚亮，揉着面团，橘猫在窗台上看着。 |
| 3 | Missing the Tram / 追电车 | Action shot. Running down the street after the departing tram, apron flying. | 动作镜：追着正要开走的电车奔跑，围裙翻飞。 |
| 4 | Window Light / 车窗晨光 | Quiet close shot. Riding along, morning light through the window, sharing a bread crust with the cat. | 静镜近景：车行途中，晨光透窗，与猫分食一块面包边。 |
| 5 | First Customer / 第一位客人 | Closing shot. Opening the shop door as the first customer arrives, bread steaming. | 收束：开门迎来第一位客人，面包还冒着热气。 |

**出图 prompt（逐条复制）**

**shot-01.jpg**
```
Soft watercolor anime style, warm morning light, gentle pastel palette, delicate line work. Wide establishing shot at sunrise: the rooftops of an old European-style town seen from above, tram wires crossing the pale sky, a small tram turning a corner far below, warm light catching the chimneys and awnings. No figures in focus. Horizontal 16:9 framing.
```

**shot-02.jpg**
```
Soft watercolor anime style, warm morning light, gentle pastel palette, delicate line work. Interior medium shot in a small bakery at dawn: a young baker's apprentice girl with dark hair in a single braid tied with a yellow ribbon, wearing a flour-dusted white apron over a soft blue dress, kneading dough on a wooden counter, flour dust floating in the light. A plump orange tabby cat with a white chest patch watches from the window sill. Horizontal 16:9 framing.
```

**shot-03.jpg**
```
Soft watercolor anime style, warm morning light, gentle pastel palette, delicate line work. Dynamic action shot on a cobbled street: a young baker's apprentice girl with dark hair in a single braid tied with a yellow ribbon and a flour-dusted white apron over a soft blue dress, running hard after a departing tram, apron and braid flying behind her, a paper bag of bread clutched to her chest. Morning light rakes low between the buildings. Horizontal 16:9 framing.
```

**shot-04.jpg**
```
Soft watercolor anime style, warm morning light, gentle pastel palette, delicate line work. Quiet close shot inside a moving tram: a young baker's apprentice girl with dark hair in a single braid tied with a yellow ribbon and a flour-dusted white apron over a soft blue dress, sitting by the window with morning light falling across her face, breaking off a crust of bread and offering it to a plump orange tabby cat with a white chest patch curled on the seat beside her. Horizontal 16:9 framing.
```

**shot-05.jpg**
```
Soft watercolor anime style, warm morning light, gentle pastel palette, delicate line work. Closing shot at a bakery storefront: a young baker's apprentice girl with dark hair in a single braid tied with a yellow ribbon and a flour-dusted white apron over a soft blue dress, holding the shop door open with a bright smile as the first customer steps in. Fresh loaves steaming in the window display, the orange tabby cat with a white chest patch sitting by the doorway. Warm morning light floods the entrance. Horizontal 16:9 framing.
```

## A.6 A 部分验收（全量三模板，**二期**收口用）

- [ ] 22 张图齐全，命名与目录严格按 §A.1
- [ ] 尺寸正确（分镜 1536×864、角色 1024×1024），单张不超体积上限
- [ ] 同模板内主角**一眼可辨为同一人**（不追求像素级一致）
- [ ] 三个模板画风彼此明显不同
- [ ] 无水印、无签名、无可辨识的第三方 IP 元素

## A.7 一期验收（模板一 8 张 · 我方执行）

分两档：**机器判定**的直接跑测试，**目视判定**的逐张看。机器档不过就退回重出，不进目视档。

### 机器判定（4 条，测试即闸门）

下面这个测试文件随 Part B 集成 PR 落地为 `test/features/studio/sample_assets_test.dart`
（沿用 `test/features/showcase/showcase_assets_test.dart` 的守卫思路：**尺寸/体积/存在性/
pubspec 声明**四条一次钉死，防止有人日后换图换崩、或漏声明导致打包后全是 broken 占位）：

```dart
// 一期示例资产守卫：尺寸、体积、齐全性、pubspec 声明。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dir = 'assets/samples/homecoming';

  Future<ui.Image> decode(File f) async {
    final codec = await ui.instantiateImageCodec(await f.readAsBytes());
    return (await codec.getNextFrame()).image;
  }

  Future<void> check(
    String name, {
    required int w,
    required int h,
    required int maxKb,
  }) async {
    final f = File('$dir/$name');
    expect(f.existsSync(), isTrue, reason: '缺图：$dir/$name');
    expect(f.lengthSync(), lessThanOrEqualTo(maxKb * 1024),
        reason: '$name 超体积上限 ${maxKb}KB（实际 ${f.lengthSync() ~/ 1024}KB）');
    final img = await decode(f);
    expect(img.width, w, reason: '$name 宽应为 $w,实际 ${img.width}');
    expect(img.height, h, reason: '$name 高应为 $h,实际 ${img.height}');
  }

  test('分镜图 6 张：1536×864 / ≤220KB', () async {
    for (var i = 1; i <= 6; i++) {
      await check('shot-0$i.jpg', w: 1536, h: 864, maxKb: 220);
    }
  });

  test('角色参考图 2 张：1024×1024 / ≤160KB', () async {
    for (final n in ['character-portrait.jpg', 'character-full.jpg']) {
      await check(n, w: 1024, h: 1024, maxKb: 160);
    }
  });

  test('pubspec.yaml 声明了 assets/samples/homecoming/', () {
    expect(
      File('pubspec.yaml').readAsStringSync().contains('- $dir/'),
      isTrue,
      reason: 'pubspec 未声明 $dir/ → 打包后示例图全变 broken 占位',
    );
  });
}
```

> 若 `ui.instantiateImageCodec` 在当前 test binding 下不可用，退化方案是纯 Dart 解析 JPEG
> 的 SOFn 段读宽高（无需新依赖），断言不变。

第 4 条机器判定不在上面的测试里，验收时手工跑一次：

```bash
git status --short assets/    # 期望只多出 assets/samples/homecoming/ 8 个未跟踪文件,别的一律没有
```

### 目视判定（3 条）

- [ ] **角色一致性**：6 张分镜 + 2 张角色图里的旅人一眼可辨为同一人（斗笠 / 蓑衣 / 红围巾
      三锚点齐全；不追求像素级一致）
- [ ] **缩略图可读性**：把每张缩到 260 px 宽看一眼，主体仍可辨、红围巾仍可见
- [ ] **干净**：画面内无文字/字幕/水印/签名/伪汉字，无可辨识的第三方 IP 元素

### 验收通过之后

图不单独提 PR。直接进 Part B 集成分支 `feat/demo-sample-storyboard`，与
`pubspec.yaml` 声明、`createSample` v2、ARB 新键、上面这个守卫测试**同一个 PR** 落地——
这样 CI 才真正跑到这些资产，而不是让它们在仓库里躺成无人引用的死重。

---

# Part B — 集成任务

> A 的图到手后执行。**一期只集成模板一**（`homecoming`，8 张 ≈ 1.8MB）——先把管线打通并验收
> 画质基准；模板二/三的图先留在分支里不进 `pubspec.yaml`，二期加它们就是纯数据活。
> 理由：安装包现为 mac 68MB / win 71MB，一次性 +4.5MB 不划算冒险；且一期若要改规格，
> 只返工 8 张。

## B.1 目标状态

用户点「创建示例项目」后，打开画布即看到：

```
[Shot 1] ──narrative──> [Shot 2] ──> [Shot 3] ──> [Shot 4] ──> [Shot 5] ──> [Shot 6]
   │                        │
 data 边                  data 边
   ↓                        ↓
[Image result 成品图]   [Image result 成品图]   …（每镜一张，已经是画好的图）
```

- 一条风格泳道，`stylePrompt` = 模板一风格串
- 一个项目级角色「蓑衣旅人」，参考图 2 张已落盘
- 6 个 shot 节点，`type_config.shot_notes` = 该镜英文备注（点开 Inspector 即可「用本镜备注生成图像」）
- 6 个 image result 节点，`type_config.image_url` 指向**项目目录内**的成品图
- 画廊里立刻有 6 张产物，可直接玩筛选 / 存为角色 / 导出视频（导出需 ffmpeg，图片不适用）

## B.2 关键设计约束（照做，别自创）

**① 打包资产 ≠ 落库路径。** 节点 `image_url` 存的是**画布相对路径**
（`FileResolverService.resolve(projectId, canvasId, rel)` 语义，形如 `images/shot-01.jpg`），
而资产在 `assets/samples/...` 是 Flutter bundle 内的路径。**必须在建示例时把 asset 字节
写进项目目录**：`rootBundle.load(assetPath)` → `File(resolver.resolve(...)).writeAsBytes(...)`。
**绝不能**把 `assets/...` 路径直接存进 `image_url`——那会让导出/画廊/删除全线错位。

**② 文件落盘与单事务的边界。** 现有 `createSample` 是 `uow.run` 单事务
（`canvas_bootstrap_controller.dart`）。文件写盘**不能**放进事务闭包里（事务回滚不会删文件）。
采用与 LB-12 项目导入同款的 **staging-first** 顺序：

1. 先把 22→8 张字节写进项目目录（若中途失败，删已写文件，直接返回失败，此时 DB 干净无痕）
2. 再 `uow.run` 单事务落库（project / canvas / lane / character / nodes / edges）
3. 事务失败 → 补偿删除第 1 步写下的文件（best-effort，失败仅 log）

**③ 角色参考图走 CharacterAssetService**，不要自己拼路径。先把角色图写到临时位置（或直接写
项目 `characters/` 目录），再 `importImage(projectId:, sourceAbsolutePath:, fileBaseName:)`
拿回项目相对路径存 DB。接口见 `lib/core/interfaces/character_asset_service.dart`。

**④ 文案分层不能破。** `CanvasBootstrapController` **不许触 l10n**（现有注释写死了这条）。
镜头备注等用户可见文案由 UI 层（`studio_home_screen` / `onboarding_dialog` / `canvas_empty_state`
三个入口）从 ARB 读出后，经扩展后的 `SampleSeed` 传进去。

**⑤ 节点布局**：6 个 shot 节点沿 X 轴等距排布（间距建议 360），Y 落在泳道带内；每个 image
result 节点排在对应 shot 节点正下方（Y + 260 左右）。参考现有 `kSampleNodePosition`
（`Offset(120, 90)`）作为第一个节点的锚点，别让节点跑出首屏视野。

## B.3 落库清单（单事务内）

| 顺序 | 写什么 | 关键字段 |
|---|---|---|
| 1 | project | name = ARB 传入的示例项目名 |
| 2 | canvas | projectId, name |
| 3 | style lane | label, stylePrompt = 模板风格串 |
| 4 | character | name（旅人）、referenceImagePaths = 两张图的项目相对路径 |
| 5 | shot 节点 ×6 | type=`shot`, role=`config`, laneId, typeConfig=`{shot_notes: <该镜英文备注>}` |
| 6 | image result 节点 ×6 | type=`image`, role=`result`, sourceNodeId=对应 shot 节点, typeConfig=`{image_url: 'images/shot-0N.jpg'}` |
| 7 | narrative 边 ×5 | shot(N) → shot(N+1)，`edge_type='narrative'` |
| 8 | data 边 ×6 | shot(N) → image result(N)，`edge_type='data'` |

`EdgeType` 枚举见 `lib/features/canvas/models/canvas_edge.dart`（`data` / `narrative` /
`generation_source`）；UoW 可用仓储见 `postgres_unit_of_work.dart` 的 `RepositoryScope`
（nodes / edges / canvas / projects / styleLanes / characters 都在）。

> **关于 result 节点的 `source`**：已核实 `001_init.sql:92` 的 `source_node_id` 是**可空 FK
> 且无类型约束**（`REFERENCES nodes(id) ON DELETE SET NULL`），schema 层不限制 source 必须是
> image config 节点——所以上表第 6 行让 result 直接指向 shot 节点在**数据库层完全可行**。
> 「result 必须有 source」是代码/产品层约定（GA-5 卡面 #9），本方案照样满足。
>
> **可选升级（若想让示例更"可再创作"）**：每镜改建三节点
> （shot → image config → image result），config 节点 `typeConfig` 填
> `{prompt: <该镜英文备注>, character_ids: [<旅人 id>]}`。好处是用户点开 config 节点就能直接
> 改提示词重跑生成，示例从"只能看"变成"能改能跑"。代价是节点数 12→18、布局更挤。
> **推荐一期先做两节点方案**（简洁、先验证管线），三节点留作二期增强。

## B.4 ARB 新增键

命名沿现有 `sample*` 前缀风格，en/zh **同 commit** 双写，改完跑 `flutter gen-l10n` 并提交
`lib/l10n/generated/`：

```
sampleHomecomingProjectName     示例项目名
sampleHomecomingCanvasName      示例画布名
sampleHomecomingLaneLabel       泳道名（如「水墨」/ Ink Wash）
sampleHomecomingCharacterName   角色名（蓑衣旅人 / The Traveler）
sampleHomecomingShot1Title … Shot6Title    镜头名 ×6
sampleHomecomingShot1Notes … Shot6Notes    镜头备注 ×6（内容取 §A.3 表格的 EN/ZH 两列）
```

**风格串（`laneStylePrompt`）与出图 prompt 一律不进 ARB**——它们是模型合约，仓库铁律禁止
i18n（`docs/CLAUDE.md` i18n 节）。作为英文常量放在 `lib/features/studio/` 下的
`sample_templates.dart` 之类的常量文件里。

## B.5 pubspec 与资产声明

```yaml
  assets:
    - assets/fonts/
    - assets/licenses/
    - assets/showcase/
    - assets/samples/homecoming/      # 一期只加这一行
```

同时在 `docs/` 记一句资产来源（AI 生成、无第三方版权、不进 `THIRD-PARTY.md`）——
建议直接加在本文件末尾的「变更记录」，或 `docs/BOARD.md` 近期落地行里带一句。

## B.6 测试计划

| 层 | 测什么 |
|---|---|
| 单测（controller） | `createSample` v2 落库结构：节点数=12、narrative 边 5 条且首尾相接、data 边 6 条、result 节点 image_url 均为 `images/` 相对路径且非 asset 路径、角色带 2 张参考图 |
| 单测（失败路径） | 文件落盘中途失败 → 不建任何 DB 行；事务失败 → 已落盘文件被补偿删除 |
| widget 测 | 三入口（向导 / Studio 空态 / 画布空态）点击后走到同一 createSample，SampleSeed 从 ARB 取值不为空 |
| 回归 | `test/features/studio/` 与 `test/app/app_routing_test.dart` 既有用例保持绿 |

## B.7 执行规程（仓库铁律，逐条照做）

1. **切分支**：`git checkout -b feat/demo-sample-storyboard`（main 禁止直接提交）
2. **TDD 先红后绿**：先写测试跑红，再实现
3. **自查闸门四条**（全过才算完成）：
   - `C:\Users\Kerro\flutter\bin\flutter.bat analyze lib test` → 0 issue
   - `C:\Users\Kerro\flutter\bin\flutter.bat test --exclude-tags golden` → 仅允许
     `node_card_golden_test.dart` 的 3 个 Windows 像素假阳性
   - ARB en/zh key 集完全一致（`test/l10n/arb_hygiene_test.dart` 会验）
   - `git status` 无意外文件
4. **零硬编码**：颜色/字号/间距全走 `lib/theme/` token；用户可见文案全走 `context.l10n`
5. **错误处理**：只捕具体 `InkError` 子类，禁 `catch Exception/dynamic`
6. **文档同步**（同 commit）：`docs/BOARD.md` 近期落地表加行、`lib/features/studio/README.md`
   （若有）、本文件的执行状态
7. **PR**：conventional commit → push → PR → CI 五件套（analyze+lint / test+coverage 70% 闸 /
   golden / release scripts / secret-scan）全绿 → squash 合并

## B.8 B 部分验收

- [ ] 全新装机首启 → 走向导创建示例 → 画布里直接看到 6 镜成品图 + 分镜链
- [ ] 点任一 shot 节点 → Inspector 有备注 → 「用本镜备注生成图像」可正常新建 config 节点
- [ ] 打开画廊 → 6 张图在列 → 筛选/存为角色可用
- [ ] 角色区能看到「蓑衣旅人」且有 2 张参考图
- [ ] 全程无网络请求、无需 API key
- [ ] 删除示例项目 → 项目目录下的图一并清理（走既有删除链，无孤儿）

---

## 附：随包资产来源登记

仓库内所有随安装包分发的示例图，来源与权利状态在此登记（`THIRD-PARTY.md` 只登记
第三方许可证义务，AI 生成的自有资产不进那里）：

| 资产 | 规格 | 来源 | 权利 |
|---|---|---|---|
| `assets/showcase/ink-wash-mountains-square.jpg` | 1024×1024 / 246KB | AI 生成（Codex 内置出图，2026-08） | 自有，无第三方版权/水印/可辨识 IP |
| `assets/showcase/ink-wash-storyboard-wide.jpg` | 1536×864 / 297KB | 同上 | 同上 |
| `assets/samples/**`（本说明书 A 部分产物） | 见 §A.1 | 待生成 | 生成后按同格式登记 |

> 上表前两张的体积（246KB / 297KB）超过 §A.1 给同规格定的 220KB / 160KB 上限——
> 它们早于本说明书产生，按历史豁免保留，仅备案不返工。新出的 22 张按 §A.1 执行。

## 变更记录

| 日期 | 内容 | 执行者 |
|---|---|---|
| 2026-08-06 | 初版：A 出图任务（3 模板 22 张全 prompt）+ B 集成任务（一期只集成 homecoming） | Claude |
| 2026-08-06 | 补随包资产来源登记表（评审 P3-1） | Claude |
| 2026-08-07 | §0 改写（原「main 有未提交改动」指令随 #214 合并作废）；新增 §A.0 一期投喂指令（落点/规格/页面说明/禁做项/回报格式）与 §A.7 一期验收（守卫测试代码 + 目视三条） | Claude |
