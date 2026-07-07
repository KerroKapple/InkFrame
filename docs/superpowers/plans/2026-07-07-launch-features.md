# 上线规划:功能模块 Epic 任务卡(2026-07-07)

> 本文冻结于 2026-07-07(main@b2be25e)。开卡前先按当前 main 复核 file:line;完成状态记 BOARD/MASTERPLAN,不回写本文。
> MASTERPLAN §2 的明细。基于 main@b2be25e 行级核实。开工前先读 `docs/EXECUTION-PLAYBOOK.md`。
> ⚠️ **时效校正**:本规划审计时 PR #143(导出 UI 入口)尚未合入——**EX-1 已基本交付**
> (画布顶栏按钮+对话框+position.x 排序+手动调序+ffmpeg 缺失文案),剩余增量见 EX-1′。
> 所有卡默认验收底线:analyze 干净、全测绿、ARB en/zh 齐平、全 token、只捕具体异常、conventional commits。

## 0. 前置事实核查(纠偏,多卡引用)

1. **视频缩略图写侧已存在**(JobQueue 成功路径落 `thumbnail_url`,job_queue_service ~L916-946)——GA-1 是接线不是新建。
2. **duration_ms 写侧确缺**;读侧(GalleryItem/gallery_tile/CanvasNode.durationMs)全就绪。
   精确落点=`_persistRemoteUrls` 视频分支 `patch['thumbnail_url']` 同块。
3. **视频角色注入确未接**:门在 `_injectCharacterRefs` L666 `nodeType != 'image'` 即返回。
   有能力的视频 provider:wanx-r2v(maxRefImages=3)、kling-v3-omni(=4),但二者 modes 仅
   [textToVideo]——**视频门不得套用 image 的 imageToImage 条件**,否则永不触发。
4. 桌面拖拽:pubspec 无 desktop_drop;画廊是独立整屏路由——真拖拽需结构改造,v1 建议菜单动作。
5. **ProcessRunner 仅有缓冲式 run()**;ffmpeg `-progress` 解析需新增流式 `start()`。
6. registry 不可 invalidate 已确认;`_factories` 是 unmodifiable——运行时增删必须动实现类。
7. **模板→适配器目前硬绑**(di/providers.dart custom 循环恒建 OpenAICompatibleImageProvider)——
   第二模板的前置是分派表(~20 行,先落不亏)。
8. narrative 排序 util 不存在——序列预览与导出必须共享同一个新 util(SB-5)。
9. **result 节点铁律**:addNode assert role==result → sourceNodeId != null——画廊发送到画布必须建
   config+result 节点对。
10. 新模型一律手写不可变类绕 codegen;改既有 freezed 用 `--build-filter` 定向。
11. 项目复制所需仓储方法全数存在;唯一缺口=nodes 二遍回填 source_node_id(用现有 update)。
12. FK 安全:jobs.result_node_id 已 SET NULL;edges/batch_results 对 nodes CASCADE——画廊硬删不炸。

## E1. Storyboard 流水线(核心差异化)

**完整态**:粘贴脚本→shot 链自动落地;镜头参数(时长/机位)传导生成;每镜图/视频双直达;
narrative 链可序列播放且与导出同序。

**脚本解析方案**:推荐 A 规则拆分先行(空行/每行策略,纯函数;现架构无文本 LLM 域,B=LLM 辅助
成本 ≥L 且质量不可断言,留作 AG-5 chat 模板后的可选增强)→ 决策 D-M4-1。

- **SB-1 规则脚本拆分器**(S):`storyboard/util/script_splitter.dart` 纯 Dart;
  `ShotDraft{label,notes}` 手写类;策略 blankLine/perLine;剥行首编号(`1.`/`镜头1`/`SHOT 1`/`#`);
  label=段首行截 60 字;统一 \r\n。验收:空行/编号/换行/空文本/超长段单测。
- **SB-2 脚本导入对话框+批量建链**(M,依赖 SB-1):粘贴框+策略切换+实时预览;确认→
  `unitOfWorkProvider` 单事务循环 `scope.nodes.create(type:'shot', typeConfig:{'shot_notes'},
  positionX:i*260)` + 相邻 `scope.edges.create(narrative, sortOrder:i)`;成功 invalidate
  nodes+edges;入口=FAB 菜单+空态。验收:N 段→N shot+N-1 边、失败无残留(fake UoW 回滚断言)。
- **SB-3 镜头级参数**(S):shot 面板加时长下拉(const [3,5,10,15]s → duration_ms)+机位下拉
  (全量 CameraMovement——shot 记录意图,生成时由 video inspector 现有钳制收口);
  机位文案抽共享 `canvas/util/camera_labels.dart`(video inspector 改 import,行为零变化)。
- **SB-4 shot→video 直达**(S,依赖 SB-3):仿 `_generateImageFromNotes` 加 `_generateVideoFromNotes`
  (typeConfig 带 prompt/duration_ms/camera + narrative 边;notifier/文案 await 前取好)。
- **SB-5 narrative 链排序 util**(S,**E1/E4 公共地基**):纯函数
  `orderByNarrativeChain({nodes, edges, include})`——只取 narrative 边建后继表;入度 0 为链头,
  多链头按 (dx,dy,id);同源多出边按 sortOrder 再 id;visited 防环;剩余按 position 追加;
  确定性全序。验收:单链/多链/分叉/环/孤立全用例。
- **SB-6 序列预览播放器**(L,依赖 SB-5/SB-3;弱依赖 XM-1):新 storyboard feature——
  `sequence_preview_dialog` + artifacts util(链上节点→最新 result 产物:sourceNodeId 匹配+
  role==result+url 非空;`nodes.listByCanvas` ORDER BY 为 z_index ASC, created_at ASC——
  **不能取列表序末位**,须在候选中按 created_at 取最新,row 里有该列;
  util 随 **EX-1′ 首建**(Wave 2),本卡只消费);图片停留 duration_ms
  (缺省 3s),视频经 videoPlayerServiceProvider(position≥duration 推进),无产物镜显 notes
  占位同计时;控件 play/pause/前后镜/进度点;**dispose 必须 handle.dispose**(media_kit 泄漏
  高发);入口=顶栏「预览序列」(有 narrative 边才 enable,与导出按钮同区,
  **跟随 PR #143 交付的顶栏结构**)。

## E2. 画廊二切片

**完整态**:视频有缩略图/可播/有时长;类型/画布/关键词筛选;图可存角色/发送画布;产物可删
(文件+DB 同步收敛);覆盖节点主产物与 batch slot 两路。

- **GA-1 视频缩略图接通**(S):GalleryItem 加 thumbnailRelativePath(freezed 定向重生成或手写镜像);
  controller 透传 node.thumbnailUrl;tile 有图→Image.file+播放角标(errorBuilder 回退图标),
  时长角标叠加。
- **GA-2 视频点击播放**(S,与 GA-1 同文件一人):resolve(canvas 双参根)+existsSync 守卫→
  `showVideoLightbox(context, videoPath: 绝对路径)`(签名已核实);缺失→broken 态。
- **GA-3 筛选/搜索**(S/M):`gallery_filter.dart` StateProvider 手写模型 {kind, canvasId?, query};
  SegmentedButton+画布下拉+搜索框(匹配 canvasName;prompt 搜索标注 non-goal);纯内存过滤;
  空结果复用 empty 态+清除筛选。
- **GA-4 存为角色**(S):仅 image 项;命名对话框(仿 `_promptName`/`_NameDialog`,
  image_config_inspector.dart L799-812)→
  `charactersController.createFromImage(name, absPath)`(补偿逻辑已有);分捕三类异常。
- **GA-5 发送到画布**(M,依赖 D-M4-2):画布选择对话框→**跨画布必须复制文件**(路径双根契约,
  目标=resolve(目标画布, `images/gallery-<uuid>.png`))→UoW 建 config+result 节点对
  (result 必须有 source,#9)→DB 失败删已复制文件。
- **GA-6 删除产物**(M,依赖 D-M4-3):节点主产物=UoW hardDelete(FK 安全已核实 #12)+
  **删前收集该节点全部 slot 的 output_url 文件一并物理删**(slot 行 CASCADE 但文件不会)+
  删主文件(失败仅 log);slot 单删=batchResults.hardDelete+删文件;确认文案明示
  「画布同步移除,引用它作参考图的生成会静默跳过」;invalidate 三处。
  验收含 PG 集成测一条 happy path。
- **GA-7 时长展示回归确认**(XS,依赖 XM-1):写侧落地后生成新视频确认 tile 显示 mm:ss;
  旧产物不回填(non-goal)。

## E3. 聚合器二切片

**完整态**:设置页可视化 CRUD(含 key)→写 json→生效时机明示;key 主动验证三态;≥2 协议模板;
(二期)新增即刻生效。

**registry 变异成本评估**:新增(add-only)运行时生效=L(registry 加 register、capabilities 列表
改同步可读 Notifier、JobQueue `_pickNextSchedulable` 加 contains 预检把 pending 优雅置败);
**删除运行时生效=高风险,永远走重启**(→ D-M4-4:推荐 A 编辑 UI+重启 → B add-only 两切片,C 永不)。

- **AG-1 json 写侧 API**(S/M):`custom_provider_store.dart` 独立写侧接口(ISP,不污染只读 source);
  save 前用与 `_parseEntry` 同源规则校验;**原子写(临时文件+rename)**;pretty JSON;
  不动内存 _configs(本切片维持会话内不变契约)。
- **AG-2 设置页编辑 UI(重启生效)**(M,依赖 AG-1):列表读文件真值(re-read 非 session 快照);
  表单(id 新增可填编辑只读/display_name/template 下拉/base_url/model_id,客户端校验镜像解析
  规则);**表单含 API Key 输入直接存 SecureStorage(key 不入 json)**;保存/删除→写文件→
  常驻「重启后生效」banner;删除可选清 key。
- **AG-3 key 校验体验**(S/M,可与 AG-2 并行):API Keys 行对 custom 用
  providerDisplayNamesProvider 覆盖 label(副标题保原始 id);「验证」按钮→validateApiKey→
  有效/无效/无法验证三态 chip;**网络失败绝不误报无效**。
- **AG-4 运行时新增 add-only**(L,依赖 AG-2+D-M4-4 B 档):registry 加幂等 register;
  capabilities 列表改同步可读 Notifier(image inspector initState ref.read 不变量);
  JobQueue dispatch 预检;**回归测试必须证明:注册新 provider 时运行中 job 零扰动**;
  「重启生效」banner 仅对编辑/删除显示;PROVIDER-API §13.5 同步。
- **AG-5 第二协议模板**(M,依赖 D-M4-5):**前置=模板→适配器分派表**(~20 行,单模板也先落);
  新 const 基线(保守能力位)+ SyncProviderBase 适配器 + 契约测试(仿 openai_compatible 模式);
  PROVIDER-API §13.2/§13.3 同步。

## E4. 导出二切片

**完整态**:自动 narrative 排序→异构输入可转码归一→进度+取消(无半成品残留)。

- **EX-1′ narrative 自动排序预填**(S,**EX-1 主体已随 PR #143 交付**):导出对话框默认序从
  position.x 改为 SB-5 的 narrative 链序(无链退回 position.x);列表项加缩略图
  (thumbnail_url,GA-1 同源);与 SB-6 共用 artifacts util——**裁决:util 随本卡首建(Wave 2),
  SB-6 只消费**。依赖:SB-5;**PR #143 合入 main**。
- **EX-2 转码/分辨率归一**(M/L,依赖 EX-1′;弱依赖 XM-1):接口加
  `ExportMode {streamCopy, normalize}`;normalize 走 filter_complex
  (`scale=W:H:force_original_aspect_ratio=decrease,pad=...,setsar=1,fps=30` × N → concat);
  `-c:v libx264 -crf 20 -pix_fmt yuv420p`,音频 v1 `-an`(D-M4-6);目标档按首输入宽高比选
  1080 档(来源=XM-1 的 width/height,缺省 16:9);半成品清理/临时文件/stderr 截断复用现结构;
  **命令行以 fake runner 单测逐参数锁死**(filter_complex 组串易错);对话框加「兼容模式」开关。
- **EX-3 进度+取消**(M/L,依赖 EX-1′;XM-1 弱依赖):ProcessRunner 加流式
  `start() → RunningProcess{stdout 行流, exitCode, kill()}`;ffmpeg args 加 `-progress pipe:1
  -nostats`,解析 out_time_ms;分母=Σ所选 duration_ms(缺失→indeterminate);取消=kill+
  `_deleteIfExists` 清半成品+CancelledError 态;进度 clamp 0..1 单调。
  风险:Windows kill 与句柄释放时序——删除失败仅 log。

## E5. 角色一致性进阶

**完整态**:有参考图能力的视频 provider 自动带角色图;video inspector 有角色区;角色库管理页。

- **CH-1 视频角色注入**(S/M):`_injectCharacterRefs` 门改双分支——image 保持现规则;
  **video 分支仅要求 maxRefImages>0(不得检查 modes,见事实 #3)**;注入后 mode 推断沿现逻辑
  ——即推断为 imageToVideo,r2v/omni 不校验 mode 不炸,**执行者不得顺手加 mode∈caps.modes 校验**;
  provider 侧 take(maxRefImages) 已收口不截断。验收:r2v/omni caps 的 fake 断言注入
  (**测试断言 mode==imageToVideo**),i2v(maxRefImages=0)零注入,image 回归不变。
- **CH-2 视频 Inspector 角色区**(M,依赖 CH-1):从 image_config_inspector L583-808 抽取
  `_CharactersSection` → 共享 `characters_section.dart`(参数化 node+caps,行为零变化);
  **决策说明:`_NameDialog`(L812-859)与 `_CharacterChip`(L860-928)同时被 `_PresetsSection`
  使用——需决策:留原文件共享 or 一并抽公共 widget;这不是零决策机械搬移**;
  video 侧挂 NodeInputsSection 前,门控 maxRefImages>0;顺带给 1019 行的 image inspector 减重
  (勿与 P1-17 _PromptPreview 债同窗)。
- **CH-3 角色库管理页**(M/L,可并行;入口形态 D-M4-8 默认 A 可先行):新 `features/characters/`
  整屏(路由完全仿 gallery 的 currentGalleryProjectProvider 模式,优先级 canvas>gallery>
  characters>screen);列表卡(缩略图/名称/描述/图数);改名/删除用现有 controller 方法;
  新增 `replaceImage`(importImage 命名 {id}-时间戳→update→旧文件 best-effort 删,补偿仿
  createFromImage)+`updateDescription`。

## E6. 项目复制(BOARD M1 补遗)

> ⚠️ **裁决(2026-07-08 复审)**:项目复制排**上线后**(≡ backend BP-11,复用 LB-12 机器);
> 本节三卡保留为实现细化参考,不进 M4 波次。

**完整态**:一键完整克隆(数据+磁盘),id 引用全重写,失败零残留。

- **PD-1 复制领域服务(DB 侧)**(L,依赖 D-M4-7):单 UoW 事务——projects.create('原名 (copy)')
  → characters→charIdMap → canvases→canvasIdMap → 每画布 lanes→laneIdMap →
  nodes(新 canvasId/laneId 映射/sourceNodeId 先 null/typeConfig 深拷:character_ids 经映射重写,
  **image_url 等相对路径原样**——随 PD-2 目录重命名天然有效)→nodeIdMap → 二遍回填
  source_node_id → edges(端点映射,保 role/sortOrder)→ prompt_presets。
  jobs/batch_results 不复制(D-M4-7 推荐 A);projects.cover_node_id 现无写入方恒 NULL,
  不映射(注明即可)。角色映射缺失(被软删)→该 id 丢弃(与生成链路
  静默跳过语义一致)。验收:fake 契约(id 全新/四类引用/软删不带/闭环不悬挂/事务回滚)+
  PG 集成测 happy path。
- **PD-2 磁盘复制+补偿**(M,依赖 PD-1):DB 成功后复制 projects/{old}→{new}
  (canvases/<oldCid>→<newCid> 按映射重命名;characters/ 原样;**exports/ 跳过**);
  源目录不存在容忍;任一 IO 失败→补偿 projects.hardDelete(newId)(CASCADE 清行)+删已建目录
  (best-effort)+原错误上抛。验收:复制后图片可渲染;注入 IO 失败→DB 无新项目+磁盘无残留。
- **PD-3 UI 入口**(S,依赖 PD-2):项目卡菜单 duplicate;执行中 spinner 防重;成功刷新列表
  (created_at DESC 自然置顶)。

## E7. 跨模块:产物 metadata 写侧

- **XM-1 视频元数据(duration_ms/width/height)**(M,**多 epic 阻塞点,最优先**):
  `extractFirstFrame` 返回值改 `VideoProbeResult{thumbnail, durationMs?, width?, height?}`
  (零向后兼容,直接改签名,全部实现+fake 同步);media_kit 实现顺读 player.state;
  JobQueue 落点=`_persistRemoteUrls` 视频分支 thumbnail patch 同块,probe 值非空且>0 才写;
  headless(null 注入)零行为变化;DATABASE.md 登记 type_config 元数据键清单。
- **XM-2 图片元数据(seed/width/height 含 batch slot 列)**(S/M,**与 XM-1 同窗同人**——
  同文件防冲突):新纯函数 `png_dimensions.dart`(PNG 签名+IHDR,非 PNG null);四个落盘点
  顺手解析(inline 两点 bytes 在手;remote 两点为 downloader 直落文件,需回读文件头 33 字节,
  小额外 IO);`_slotSuccessPatch` 加 width/height/seed 列
  (schema 已建未用);解析失败静默缺省。⚠️ JobQueue 两卡后若逼近 1500 行触发拆分线,先落卡后拆。

## 跨 epic 排程

**硬依赖**:SB-5→SB-6/EX-1′;**PR #143 合入 main → EX-1′/SB-6**;XM-1→GA-7(硬);
XM-1→EX-3/EX-2/SB-6(弱:缺 duration 走 indeterminate/默认比例);SB-3→SB-4;SB-1→SB-2;
AG-1→AG-2→AG-4;CH-1→CH-2;PD-1→PD-2→PD-3(上线后)。
**决策阻塞**:GA-5←D-M4-2;GA-6←D-M4-3;AG-4←D-M4-4;AG-5←D-M4-5;EX-2 音频←D-M4-6;
PD-1←D-M4-7;CH-3←D-M4-8(弱)。

**波次(波内可并行,不同执行者不踩文件;PD-1~3 已移出 M4 波次,见 E6 裁决)**:
- Wave 1:**XM-1(最优先)**、SB-1、SB-3、SB-5、AG-1、GA-1+GA-2(一人)、CH-1
- Wave 2:XM-2(接 XM-1 同人)、SB-2、SB-4、GA-3、GA-4、AG-2、AG-3、EX-1′(#143 合入后)、CH-2
- Wave 3:SB-6、EX-2、EX-3、AG-4、AG-5、GA-5、GA-6、GA-7、CH-3

**文件冲突热区**:job_queue_service.dart(XM-1/XM-2/AG-4——XM 同窗一人,AG-4 错峰);
shot_config_inspector.dart(SB-3/SB-4 一人);canvas_top_chrome.dart(SB-6 vs
**PR #143 交付的顶栏结构**——SB-6 跟随);artifacts util 文件(EX-1′ 首建,SB-6 消费);
app.dart 路由(CH-3 独占);image_config_inspector.dart(CH-2 抽取勿与 P1-17 同窗);
**Wave 内冲突**:EX-2/EX-3 同改 ffmpeg 服务+对话框(同人或先后)、AG-4/AG-5 同改
di/providers.dart、GA-3/GA-4 与 GA-5/GA-6 的 gallery 文件组;
几乎每卡都碰 ARB 双文件,遵循 rebase 惯例。
**关键路径**:XM-1→EX-3(导出闭环)与 SB-5→SB-6/EX-1′(叙事闭环);只能保一条先保 SB 线+XM-1。

**规模合计**(口径:全部 29 张;XS×1、S×9、S/M×5、M×8、M/L×3、L×3;其中 PD 三卡
(PD-1 L/PD-2 M/PD-3 S)另计上线后,M4 波次实际 26 张)≈ 2-3 个 sprint。

## 产品分叉(→ MASTERPLAN §9,D-M4-1~8)

- **D-M4-1 脚本拆分引擎**:A 规则拆分(推荐)/ B LLM / C A 先行+AG-5 后加 AI 拆分按钮。
- **D-M4-2 画廊拖入画布形态**:A 菜单动作「添加到画布…」(推荐;真拖拽需画布内抽屉改造+新依赖)/
  B 画布内抽屉+真拖拽(后续)/ C OS 级拖放。附带确认:以空 prompt config+result 节点对表达。
- **D-M4-3 画廊删除语义**:A 永久删除(行+文件,双确认)(推荐——软删留文件=孤儿债继续滚)/
  B 仅画廊隐藏 / C 软删+保文件。
- **D-M4-4 聚合器生效时机**:A 编辑 UI+重启(推荐先做)→ B 追加运行时新增(add-only)/
  C 全运行时增删(**永不**——在途任务语义无解)。
- **D-M4-5 第二协议模板**:A openai-chat-image(OpenRouter 图像模型走此形态,聚合面最大,推荐)/
  B gemini-compatible / C 延后。分派表两案共用先做不亏。
- **D-M4-6 导出转码档位**:A 单开关兼容模式=1080 档/30fps/H.264/丢音频(推荐——AI 视频多无音轨)/
  B 有音轨则 copy / C 完整参数面板(过度设计)。
- **D-M4-7 项目复制 jobs/batch 取舍**:A 都不复制(推荐——副本语义=创作数据;exports/ 也不复制)/
  B 复制终态(+M 成本)。
- **D-M4-8 角色库入口**:A 独立整屏仿 Gallery(推荐)/ B Gallery 内 tab / C 塞设置页(不建议)。
