# 第二批派工单 W8–W11 · 设计缺口与待裁决

细化画板用。格式：画板 · 功能 · 缺什么（状态 / 步骤 / 边界）→ 派工单里暂定的处理。没有写「暂定」的，派工单里也没定，要回到画板补。

## 一、和画板说法冲突、需要设计确认的（优先）
1. **ImportSearch · 系统拖入浮层**：desktop_drop 在松手前拿不到文件列表，画板上的「松手导入 3 个文件 · 图片 2 · 视频 1」画不出来。→ 暂定：浮层只写「松手导入」不带数字，数字放到松手后的通知卡里（os-drop-paste-image）。
2. **GapsCanvas N1 与 KeyMap Q1 · 下一镜继承哪些键**：两张板在镜头语言五键（camera、shot_size、camera_angle、camera_motion_strength、focal_length_mm）和批量数上说法相反。→ 暂定按 KeyMap Q1 的 A（两张板里只有它明写了「建议」）：继承 provider_id、aspect_ratio、resolution、duration_ms、batch_size、character_ids、negative_prompt、ignore_lane_style 和泳道；镜头语言、seed、prompt、shot_notes、产物、首尾帧都不继承。GapsCanvas 示意图里的镜头语言 chip 和「张数回到 1」要按这个改，或者改判。要改判只动 next-shot 的 `kNextShotInheritedKeys` 一处和两条测试。
3. **ContextMenus 与 Selection · 跨轴对齐**：ContextMenus 写「不在同一条道就置灰」，Selection 写「各自夹在自己道的带里」。→ 暂定按 Selection（align-distribute-arrange）。W12 cm-multi-select-menu 不要往 node_menu_model 里加「同道才可点」这条判据。
4. **ContextMenus 与 Selection · 分布放在哪**：ContextMenus 画成单独一行「分布 ›」，Selection 把它并进「对齐 ›」。→ 暂定按 Selection，只出「对齐 ›」一行。
5. **Selection · 多选检查器 · 视频配置的「画幅 / 种子」**：样稿给视频画了这两项，但现有单选视频检查器没有这两项。→ 暂定视频只列模型和时长。
6. **RailScript · 剧本估时**：第 02 段 16 个汉字按「4 字 / 秒」算是 ~4 秒，板上写 ~5 秒，合计 ~14 应为 ~13。GapsPanels 三个例子都符合「只数汉字、按秒向上取整、至少 2 秒」。→ 按这个算法写，RailScript 板上的数字要改。
7. **GapsPanels 与 RailScript · 时长要不要带 ~**：GapsPanels 每行时长不带 ~，RailScript 带。→ 暂定每行和合计都带 ~（估算值）。
8. **GapsPanels · 产物检查器 · 叫法**：板上写「图像」，现有 ARB 里 canvasNodeImageType 的中文是「图片」。要定一个叫法。
9. **ShellExport · 系统通知 · 导出**：导出失败只在对话框里出错误条，不出卡片，所以也不会有系统通知；导出卡的主按钮实际是「复制路径」，不是画板写的「打开文件夹」。
10. **GapsCanvas · 下一镜 · 第三个入口**：画板说检查器里已经有「下一镜」，核对后不存在。shot_config_inspector 里只有「用本镜备注生成」。→ 第三个入口改成 W11 的节点右键。
11. **GapsCanvas · 下一镜 · 按 ↵ 光标进提示词条**：这要改 canvas_prompt_bar.dart，W10 没有切片拥有它。本批不做，要另排一片。
12. **ShellExport · F6 与 ⌘K 同层**：⌘K 绑在 Navigator 里面，通知区持焦时 ⌘K 不生效，和画板写的「同层」不一致。

## 二、画板缺的状态 / 步骤 / 边界（派工单已暂定）
**ContextMenus · 停用（node-disabled-flag）**
- 停用中的节点被单独生成时，状态行写什么 → 有活动 job 时按 job 报，job 结束回到「已停用」。
- 哪些节点能停用 → 只有图像 / 视频配置节点，镜头、文本、产物置灰。
- 停用成功后没有提示 → 只在失败时出错误卡。

**Selection · 对齐 / 排布 / 整理叙事链（align-distribute-arrange）**
- 没选中的产物动不动，镜与镜之间要不要给产物列留位 → 名下产物都按 result_placement 跟着排，间距给产物列让位。
- 竖向泳道 → 沿泳道主轴排。
- 选中数量不够时按快捷键 → 弹胶囊提示。

**Selection · 包成泳道（wrap-in-lane）**
- 选区跨多条道时，「所在那条道」是哪条 → 取 sortOrder 最大的那条。
- 卡来自多条道时，撤销卡里的「X」写什么 → 加复数文案「N 张从 M 条泳道换到新泳道，风格变了」。
- 原来那条道没有风格提示词时，算不算「风格变了」 → 照板，只要原来在道里就弹卡。
- 没有选中时按 Ctrl G → 弹胶囊提示。
- KeyMap 的让位表里没列 Ctrl G / Ctrl Shift G → 定为交给输入框。

**Selection · 多选检查器（multi-select-inspector）**
- 清单行能不能点 → 不能点。
- 停用节点在清单和总价里怎么显示 → 行尾写「已停用」，不计价。
- 多选时「历史」页签显示什么 → 沿用空态那句。
- 有节点在生成时能不能改共有参数 → 整组置灰并写原因。

**UndoClipboard · 粘贴文字（clipboard-text-paste）**
- 剪贴板为空、全是空白、读取失败 → 弹两句胶囊提示。
- 「长段落」的判据 → 用剧本导入的默认拆分切出 ≥ 2 块。
- 拆完镜后原文本节点留不留 → 保留；粘贴和拆镜是两步撤销。
- W8 胶囊「按剧本拆镜…」传的落点（文本节点下方）在画布已有链时会被 W11 的「接链尾」忽略，新镜可能离文本节点很远。

**ImportSearch · 系统拖入 / 粘贴图片（os-drop-paste-image）**
- 拖入文件夹、读不到的文件、只拖网页链接 → 补三条跳过理由，文件夹不递归。
- 在 Finder / 资源管理器复制文件后按 Ctrl V → 走拖入同一条路，排在读图片之前（mac 上读图可能读到文件图标）。
- 系统文件拖到配置卡上 → 当成落在空白处，不弹菜单。
- 粘贴图片的卡片标题「剪贴板图像」 → W2 导入入口收不了标签时，退成文件名 `clipboard-<时间>.png`。
- 平台限制：Windows 上 pasteboard 给的是 XRGB BMP，透明 PNG 贴进来会是黑底。

**ImportSearch · 角色拖放（rail-drag-characters）**
- 拖到空白、文本 / 镜头卡、产物卡上，重复挂同一个角色，拖动途中角色被删 → 各弹一句胶囊提示。
- 拖影和原位样式 → 沿用 W5 素材格的写法。

**ImportSearch · 查找条（canvas-find-bar）**
- 和舞台顶部现有浮层（连线提示、多选计数、错误横幅）怎么叠放 → 没画，也没修；要修得改 canvas_view.dart，W9 归 os-drop。
- 零命中时卡片变不变暗 → 照字面「非命中 35%」，计数位写「无结果」。
- 命中在折叠泳道里 → 跳到时先展开那条道。
- 连线、泳道底色跟不跟着变暗 → 只暗卡片。
- 打字时动不动相机 → 不动，首次按 ↵ 才跳；关闭时选中当前项。
- 输入法组字中按 ↵ → 只确认组字。
- mac 上文字里按 Ctrl F → 只有平台主键（⌘F / Ctrl F）在文字里接管，mac 文字里的 Ctrl F 留给 emacs 前移一格。

**GapsPanels · 大纲改名（outline-rename-menu）**
- 没有键盘入口（F2 / ↵） → 只做双击。
- 名字超长 → 上限 200 字，与 DB CHECK 一致。
- 改名中节点被删、列表重建、行被筛选滤掉 → 没画。
- Esc 和 Esc 阶梯第 4 层「失焦」冲突（失焦 = 保存） → 改名框自己消费 Esc。
- 产物子行能不能改名 → 不做。

**GapsCanvas · 下一镜（next-shot）**
- 锚点在折叠泳道里 → 照建，并展开那条道。
- 连按时上一笔还在写库 → 丢弃新按键。
- 专属撤销步名「新建下一镜」 → 暂沿用 W4 新建命令的通用标签。

**GapsCanvas · 加入叙事链末尾（node-menu-append-chain）**
- 全在链上、全是文本、全是孤儿产物时的置灰原因 → 补了两句。
- 部分已在链上 → 胶囊加「· 跳过 N 个已在链上的」。
- 链尾没有镜号时「第 N 镜」写什么 → 改成「已接到「名字」之后」。
- 连成新链时的胶囊 → 「已连成新叙事链 · N 镜」。
- 菜单分组「做 | take | 归类 | 定位 | 停用 · 删除」要挪 menu_registry 里现有的行，本批切片只能追加；由主 Agent 合入时统一调。

**TakesCost · 批量计划 / 执行 / 对话框（batch-run-*）**
- 「只跑过期和没生成的」模式下已是最新的节点 → 不列，对话框给空态。
- 「全部」模式下已是最新的那一行 → 写「重新生成」。
- 缺尾帧 → 也跳过；缺参考图 → 照跑。
- 节点已有任务在跑 → 「生成中 · 跳过」。
- 只跑过期模式下上游要重跑、下游是最新的 → 下游跟着跑，记「已过期」。
- data 边成环 → 按叙事链序排，环内依赖不算。
- 预计总耗时怎么算（并发怎么折算、价格未知的行算不算） → 没画，留给 batch-run-dialog 定。
- 估时不区分批量数和视频时长；加载中 / 读库失败 → 都写「—」。
- InkOverlayDialog 的标题栏放不下分段切换 → 挪到正文第一行；要严格照画板，得给组件加 titleTrailing 插槽（theme 层，没人拥有）。
- 从选中集打开时用不用记住的那一档 → 一律「全部」，不写回偏好；记住上次只对链 / 组 / ⌘K 生效。
- 空态、行首序号的取法、大纲组头「运行这组」的样子、链 / 组里没有能生成的节点时的反馈 → 没画。
- 任务弹层的批次头，「等上游」「上游失败 · 未提交」「提交失败」三种行 → 没画；胶囊把等上游的算进「排队」。
- 应用重启后批次 → 只放内存，重启就丢。
- 模型不支持首帧却连了首帧边，生成侧会抛 `first_frame_unsupported`（generation_controller 第 288 行），「照连 + 黄字」实际是在预告生成会失败；批量计划不预判，执行时会变成「提交失败」。
- 配置节点当首帧源时，`_resolveRefImages` 读的是源节点自己的 image_url，永远是空。W5 edge-follow 只挪「源是旧 take」的边；batch-run-executor 第 9 条有条件修法。

**TakesCost · 当下一镜的首帧（tc-next-shot-first-frame）**
- 链尾时子菜单写什么 → 只有一行「新建下一镜（视频配置）」。
- 配置卡还没有成片 → 父项置灰。
- 镜头节点没写备注 → 那一行置灰。
- 镜头后面已经接着视频配置 → 改接那个视频配置，不新建。
- 菜单行要不要提示「模型不支持首帧」、接好后有没有反馈、导入的图片出不出这一项、尾帧不支持时要不要同样出黄字 → 没画。

**ShellExport · 任务计时 / 系统通知 / F6（job-timing、job-eta、system-notifications、f6-notification-region）**
- 第一次进度之前注册表一直是 JobQueued（generation_controller 第 398 行），状态字和耗时阶段对不上 → 以计时表为准。
- 排队中被取消的任务没有「用时」 → 只写「已取消」。
- 失败卡要不要加「用时」 → 只给成功卡加。
- 系统通知合并成一条时的标题、正文、点击行为 → 标题「N 件事已完成 / · K 个失败」，点击打开铃铛历史。
- 2 秒合并窗口到点时用户已经回到窗口 → 不发。
- 样稿通知里的出处行（项目 · 画布）和 provider 名，现有卡片数据里没有。
- macOS 上 local_notifier 0.1.x 有没有查询 / 请求权限的接口要核对；没有的话「系统里已关闭」在 macOS 上出不来。
- 铃铛承接不了历史时（上面压着对话框、或启动失败页没有铃铛），没有卡按 F6 → 只播报「没有通知」。
- 按 ↵ 执行主按钮后焦点去哪、历史行按 ↵ 做什么（这些行现在点不了）、通知区开着时来了新卡焦点跟不跟 → 派工单里定了默认，画板没画。

**RailScript / GapsPanels · 剧本表与导入（script-tables、script-import）**
- 一张画布能有几份剧本、剧本标题、删整份剧本 → 一画布一份（UNIQUE(canvas_id)），文档表不带 title / deleted_at。
- 导入接链尾：链尾在视口外时新镜怎么让用户看到、链尾在泳道里时新镜进不进那条道、落点压到别的卡 → 不动相机和选中，跟链尾同道，落点不避让。
- 整次导入算一步撤销：要新命令子类，W11 没有切片能改 canvas_command.dart → 复用 W4「新建多个节点和边」的命令；那条命令不接受多节点的话，本片先不登记撤销。

**ImportSearch · @ 记号（mention-token-core）**
- 项目包是全保真导出，映射不到的角色在包里也没有名字，「@名字」这一支只能在纯函数测试里验证。plan.md 第 3 节「remapper 映射不到的角色记号变成『@名字』」这条验收要改写。
- 记号在这些地方怎么显示没画：检查器「完整提示词」预览（image_config_inspector 第 609 行）、产物检查器和画廊的提示词行、大纲和 ⌘K 筛选。W12 开始写记号后，这些地方会露出原始 uuid。建议并进 W12 prompt-bar-mention-ui，或在它之前加一片「显示侧 stripToNames」。
- 提示词里只剩已删角色的记号时，「生成」按钮仍能点，提交时才报错，generate_gate 缺这条判断。

**GapsPanels · 产物检查器（result-inspector-align）**
- 只画了对齐前的样子，节点头对齐后的格式和分隔符没画。
- 图标集 v1 缺「图片丢失」和「圆圈播放」两个字形：派工单按 icons.js 的工具函数手写了路径，设计源 icons.js 要补同样两条。ink_icon_sheet golden 基线会变，要在 CI 上重新生成。

## 三、主 Agent 在本批里的裁决（执行时照此办）
- node-disabled-flag 可以新建 `shortcuts/disable_keys.dart`（Shift D，KeyMap Q4 → B），注册表追加一行。
- canvas_command.dart 不扩权：W8 只有 wrap-in-lane、W9 只有 outline-rename-menu 能改它；对齐、停用、下一镜、首帧、剧本导入都沿用通用标签，专属步名留给后续波次。
- node-menu-append-chain 可以往 menu_registry 追加两行（每项一行）。
- next-shot 有条件地可改 `canvas_menu/canvas_menu_host.dart` 里新建菜单的分派那一行（前提：W0 把分派放在 host 里）。测试一律用 test/_harness 的共享 fake，以免和 script-tables 的 RepositoryScope 改动冲突。
- rail-drag-characters 可以改 `characters_section.dart`（只加 didUpdateWidget）。舞台分派里的角色分支、悬停判据这两处 canvas_view.dart 接线，等 os-drop-paste-image 合入后由主 Agent 补。
- system-notifications 可以改 `core/interfaces/toast_service.dart`、`test/_harness/fake_toast_service.dart`（show 加 elapsed）、`export/widgets/export_video_dialog.dart`；W12 toast-category-mute 排在它之后再改 show。
- f6-notification-region 有条件地可改 `settings/widgets/shortcuts_section.dart`（前提：W0 之后穷举 switch 还留在这个文件里）。
- `app_action_ids.dart` 跟 app_action_catalog 一样按注册表例外处理，每片只追加一个常量。
- app_preferences 的 hashCode：W10 system-notifications 改成 `Object.hashAll`，W11 batch-run-dialog 只追加。

## 四、合入后要统一的重复实现
- 链尾判据：script-import（scriptChainTail）和 node-menu-append-chain（append_to_chain）各写了一份，语义相同。
- 首帧链尾新建视频配置：tc-next-shot-first-frame 自己算落点，并照抄了 shot_config_inspector 的 `_generateVideoFromNotes` 判据；next-shot 合入后应改走 createNextShot。
- 能力位判据：rail-drag-characters（characterRefsSupported、edgeReferenceImageCount）、CharactersSection 的私有判据、multi-select-inspector 的 provider_capability_fields.dart，三处重复。
- 价格文案键：multi-select-inspector 的 costApproxUsd、costUnknownMore 和 node-cost（W2）可能同义；同义就复用 W2 的键，W11 / W12 也用同一个。
- 可达性：job-eta 的 recentDurationsMs 不进 JobRepository，job_repository_reachability_test 覆盖不到；W11 运行对话框合入前，生产代码里没有它的调用点。
- inspector_submit_controller：运行对话框用 flushPendingWrites，B8（写失败后不再重试）仍在；要根治，得加一个「只落盘、不提交」的入口（这个文件没人拥有）。
- docs/CLAUDE.md 由主 Agent 统一更新：lib/core/text/、storyboard/models/script_document.dart、两张新表、图标数 45 → 47、新依赖（desktop_drop、pasteboard、local_notifier）。
