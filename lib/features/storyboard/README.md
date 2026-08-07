# storyboard —— 序列预览（SB-6）

把画布上的 narrative 链当成一条片子，从头播一遍。

## 分层

```
models/sequence_shot.dart    播放清单条目（一镜放什么、放多久）
util/sequence_builder.dart   画布节点+边 → 播放清单（纯函数，全单测）
widgets/sequence_preview_dialog.dart  只负责"放"与"推进"
```

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

- `sequence_builder_test.dart`（14 例）：折叠、时长优先级、取最新产物、跳过规则
- `sequence_preview_dialog_test.dart`（12 例）：handle 生命周期、推进语义、控件门控
- `canvas_top_chrome_sequence_test.dart`（4 例）：入口可用性门控

media_kit 真播放需要 GPU / 原生层，测试一律走 fake handle —— 真实播放靠手动回归。

## 本切片不做

时间轴刮擦（跳到任意时刻）、导出与预览共用一条时间线、转场、音频。
