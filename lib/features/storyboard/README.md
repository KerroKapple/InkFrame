# storyboard —— 脚本进画布，分镜出片子

一头是**入口**（SB-1/SB-2：粘一段脚本 → 一条串好的分镜链），另一头是**出口**
（SB-6：把这条链当成片子从头播一遍）。

## 分层

```
models/sequence_shot.dart    播放清单条目（一镜放什么、放多久）
util/script_splitter.dart    粘贴的文本 → 分镜草稿（纯 Dart，无 Flutter 依赖）
util/sequence_builder.dart   画布节点+边 → 播放清单（纯函数，全单测）
providers/script_import_controller.dart  分镜草稿 → 画布上的 shot 链（单事务落库）
widgets/script_import_dialog.dart        粘贴 + 策略切换 + 实时预览
widgets/sequence_preview_dialog.dart     只负责"放"与"推进"
```

## 脚本拆分（SB-1）

`splitScript(text, strategy)` 把一段粘来的文本拆成 `ShotDraft{label, notes}`。
**纯规则，零 LLM**（D-M4-1 拍 A 档）—— 没有 API key 也能用，行为可断言、可单测、不花钱。

两种策略：`blankLine`（空行分段，适合有段落结构的剧本）、`perLine`（每行一镜）。

最容易写漏的是**剥行首编号**。用户粘来的文本十有八九带 `1.` / `镜头1` / `第3镜` /
`SHOT 1` / `# `，留着会污染 prompt（"1. 山径破晓" 会让模型去画一个数字 1）。但也不能
剥过头 —— "1920 年代的街道"、"3D 渲染质感"里的数字是内容。分界：

- **有词锚的**（`镜头N` / `第N镜` / `SHOT N` / `Scene N`）→ 分隔符可有可无
- **光秃秃的数字** → **必须**跟分隔符（`.` `)` `、` `：` `-`），否则不认

只剥**段首那一行**：段内的 "2 号机位跟拍" 是内容，不是第 2 镜。markdown 井号单独一趟剥，
因为它既可独立出现（`# 山径破晓`）也可叠在编号前（`### Shot 1 dawn`）。

`label` 是段首行截 60 字（展示用），`notes` 恒为全文 —— 截断不该丢内容。

## 批量建链（SB-2）

对话框负责「看」：粘贴框 + 策略切换 + 实时预览（几镜、每镜叫什么）。拆分规则再讲究也有
猜错的时候，用户得先看见结果才敢按创建 —— 切换策略后预览立刻重算，等于把规则摊开给人验。

`ScriptImportController.importDrafts` 负责「落」：N 个 shot 节点 + N-1 条 narrative 边
**全部收进单个事务**。半条链（几个建好的散镜 + 几条边）比一个错误提示难收拾得多 —— 用户既
不知道哪几镜落地了，也没有一键撤销，所以失败必须零残留。

两处容易踩：

- **不走 CanvasNodesController**：它一次只建一个节点，也不参与事务。这里直接经
  `unitOfWorkProvider` 的 scope 写库，落地后再 invalidate 节点与边两个控制器让内存态跟上。
- **provider 不加 autoDispose**：调用方只 `ref.read` 拿一次控制器（不订阅），autoDispose
  会在 read 之后立刻销毁 ref，事务 await 完再 invalidate 就撞上已销毁的 ref，画布刷不出新链。

落点：第一镜落视口中心，后续沿 x 轴每 `kShotChainSpacingX`(260) 排开（shot 卡宽 240，
留 20 走线余量）。入口 = 画布 FAB 菜单「导入脚本…」+ 空态 CTA「导入脚本」。

排序复用 SB-5 的 `canvas/util/narrative_order.dart`，产物查找复用 EX-1′ 首建的
`canvas/util/node_artifacts.dart` —— 本 feature 不再造第二套（卡面裁决）。

## 为什么 builder 里有「折叠」

用户从 shot 节点点「用本镜备注生成图像」，建出来的真实拓扑是：

```
shot ──narrative──> image config ──sourceNodeId──> image result
```

**config 节点也在 narrative 链上**。照单把每个链上节点都当一镜的话，一条 3 镜的分镜
会播出 6 条（shot1 占位、cfg1 出图、shot2 占位、cfg2 出图……）。而
`_generateImageFromNotes` 是当前把图接进分镜链的**唯一**入口 —— 不折叠等于这张卡不可用。

规则：一个链上节点若把自己的产物「借」给了前面的 shot，就不再单独成镜；已被借走的
产物也不会被第二个 shot 再借一次（多个 shot 指向同一个 config 时）。

## 推进规则

| 镜的类型 | 怎么推进 |
|---|---|
| 图片 / 无产物占位 | 定时器，停留 `shot.durationMs`（缺省 3s） |
| 视频 | 真实播放进度（`position ≥ duration` 即换镜），**另挂兜底定时器** |

视频那条兜底不是冗余：播放器打不开文件、进度流不动、时长拿不到时，没有它就永远卡在
这一镜。兜底给了 `durationMs + 1500ms` 余量，正常播放应当先于它触发换镜。

## media_kit 生命周期

卡面点名此处泄漏高发。约束：

- 整个对话框**只 create() 一个 handle**，换镜靠 `open()` 换源
- handle 只在 `initState` 建、只在 `dispose` 放，中途任何路径都不再 create
- **纯图片序列完全不 create**（不该为了一堆静态图唤起 media_kit）

`_epoch` 计数器防迟到回调：换镜时自增，异步回调（open 完成、position 事件）拿它比对，
不会推进一个早已翻过去的镜。

## 入口

画布顶栏「序列预览」按钮，画布上有 narrative 边才可用（可用性只 watch 边，
拖动节点不重建顶栏）。

## 测试

- `script_splitter_test.dart`（22 例）：分段策略、剥编号的边界、退化输入
- `script_import_controller_test.dart`（10 例）：链形状、落点、单事务、**失败零残留**、invalidate
- `script_import_dialog_test.dart`（6 例）：预览实时性、策略切换、成功/失败路径
- `sequence_builder_test.dart`（14 例）：折叠、时长优先级、取最新产物、跳过规则
- `sequence_preview_dialog_test.dart`（12 例）：handle 生命周期、推进语义、控件门控
- `canvas_top_chrome_sequence_test.dart`（4 例）：入口可用性门控

「失败零残留」用的 fake UoW 会**真回滚**（写入先落 staging，闭包整体成功才 commit）；
真事务的回滚语义由 `test/storage/transaction_integration_test.dart`（真 PG）兜底。

media_kit 真播放需要 GPU / 原生层，测试一律走 fake handle —— 真实播放靠手动回归。

## 本切片不做

时间轴刮擦（跳到任意时刻）、导出与预览共用一条时间线、转场、音频。
