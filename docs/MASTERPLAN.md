# InkFrame 上线总体规划(MASTERPLAN)

> **这是什么**:从当前状态(M2 完成、M3 四方向首切片落地)到 **1.0 公开上线**的完整任务库与路线图。
> 由 2026-07-07 的 7 路调研/规划(3 路联网市场调研 + 4 路仓库落地规划)合成,含每个任务的
> 做法与验收标准,可交给后续执行者(人或 AI)逐卡执行。
> **怎么用**:状态以 [`BOARD.md`](BOARD.md) 为单一事实源;本文是任务卡库与排序依据——开工一张卡,
> 先读 [`EXECUTION-PLAYBOOK.md`](EXECUTION-PLAYBOOK.md)(流水线/地雷/不变量),照卡执行,完成后
> BOARD 打勾并在本文标记。**决策区(§9)的分叉需用户拍板后才能开对应卡。**
> **维护**:任务完成 → 勾选;新任务 → 按模板入库;里程碑变化 → 同步 BOARD。

---

## 0. 总览:里程碑与主线

```
现状(2026-07-18):M1 ✅ M2 ✅ M3 🔵(四方向首切片+导出 UI 入口 #143) alpha.10 已发布(release.yml 首跑,双平台 unsigned 产物;PG 分发源+checksums 已随 PKG-2A 落,欠 Latest 卫生);M5 backend 线飞推(LB-01~04/06/07/08/09/13a/13b/14/16/17/19 已合)+**UI 线连发**(GAP-8/#164、GAP-4/#167、PL-4a/#168、PL-6/#170、CV-1+PL-1/#174、PL-2/#176、画布体验大改 #179/#180)+M4 破冰(XM-1/#177+XM-1b/#181)+发布线 UPD-1/#173、LEG-1/#147;D-7/D-8/D-BE-2/D-10 已拍(见 §9)
   │
M4 「能力完整」……… M3 各方向二/三切片:storyboard 流水线成型、聚合器可视化配置、
   │                画廊可复用、导出可用可靠 + 角色进阶
M5 「能上生产」……… 数据安全(备份/恢复/升级)、发布工程(签名/公证/更新)、
   │                onboarding、性能与回归闸门
M6 「公开上线」……… 官网 + 示例项目 + 冷启动执行(HN/Reddit/B站/小红书)+ beta 通道
   │
1.0 ………………………… 上线后按反馈迭代;远期(团队协作/本地模型/序列剪辑)见 §8
```

- **主叙事(每个决策都为它服务)**:InkFrame = **分镜/故事优先的 local-first AI 工作室**。
  模型层的"智能分镜"(可灵 3.0/即梦 Seedance)是我们编排的对象,不是竞争对象;
  我们的护城河 = 项目/角色资产/叙事结构 + 数据与 Key 的本机主权 + 直连零加价。
- **节奏原则**(项目宗旨:慢工出精品,不赶上线):里程碑无日期,只有**准入清单**;
  每张卡走 PLAYBOOK 流水线;质量投入不向进度妥协。

## 1. 市场与定位(2026-07 调研结论,来源与全表见调研存档 §10)

### 1.1 格局速读
- **云端叙事套件**(LTX Studio/即梦/可灵/Freepik):分镜能力最强,但全是 credit 加价 + 数据在云。
  可灵 3.0「智能分镜」、即梦 Seedance 2.0 九宫格分镜是**模型层能力**——InkFrame 应把它们当
  provider 接入编排,永不下场比生成质量。
- **云端节点画布**(Flora $52M 融资/Krea/Kaiber;Weavy 被 Figma ~$200M 收购):节点画布范式被
  资本重度验证,但无一 local-first。
- **开源本地阵营**:ComfyUI($500M 估值,引擎不是工作室,学习曲线是公认痛点;API Nodes 也抽成)、
  InvokeAI(纯图像,托管平台已关、团队入 Adobe)、**NodeTool(最直接近邻!口号
  "Every model. Your keys. Your canvas." 与我们几乎撞车;泛工作台非叙事优先;424★ 活跃但未成产品)**。
- **结论:半空位**——「local-first + BYO-key」不再是无人区,但「**storyboard-first 本地工作室**」
  无人齐备;**中文市场全空**(即梦/可灵全云,无任何 local-first BYO-key 桌面创作工具面向中文用户,
  且我们已内置 Kling/Wanx)。

### 1.2 定位与措辞(→ 决策区 D-1 拍板后落地到 README/官网)
- 建议主口号:**"The local-first AI storyboard studio — your script, your keys, your machine."**
  (把"分镜/故事"放进第一句,避开与 NodeTool 正面撞口号;中文:「本地优先的 AI 分镜工作室——
  你的剧本、你的 Key、你的机器」)。
- 分受众话术:对 ComfyUI 用户 =「不用自己搭图,开箱即是分镜工作室」;对云平台用户 =
  「没有 credit,只有你和模型商的直连价」。
- **红线**:不用"唯一/first"绝对化措辞(NodeTool 存在,HN 会打脸);差异化锚定在
  叙事工作流 + 数据主权,永不锚定生成质量。

### 1.3 分发与商业模式(→ 决策区 D-2/D-3)
- 渠道三件套:**GitHub Releases(主)+ winget + Homebrew cask**;MAS/微软商店暂缓
  (内嵌 PG 子进程 + 外部 ffmpeg 在商店沙盒下风险高,冷启动期不值)。
- 商业模式与 BYO-key 相容性:✅ 开源+赞助(GitHub Sponsors 起步)→ 远期团队版
  (InvokeAI $19/$49 模式);❌ credit 转售 = 定位自杀;⚠️ 云增值只能做"可选便利层且明示可绕过"。
- 个人版**永久全功能免费**(LM Studio 路线的教训:先冲用户量)。

### 1.4 冷启动 playbook(M6 执行,投入产出序)
1. **Show HN**(技术叙事完全命中:BYO-key/内嵌 PG/Flutter 桌面/local-first)——提前攒 karma,
   周二至四 9:00-12:00 ET,标题中性,首小时逐条回复,备好「为什么不用 Electron/为什么内嵌 Postgres」答辩。
2. **Reddit r/StableDiffusion + r/aivideo + r/LocalLLaMA**——发完整工作流复现帖(剧本→节点图→成片),
   非广告体。
3. **X build-in-public**:30-90s demo,前 5-7 秒先出成片再倒叙工作流,静音可看(动态字幕)。
4. **B站长教程 + 小红书长尾词**(「AI 分镜 本地」「可灵 API 工作流」类,前十条赞<500 的词)——
   中文市场竞品真空,叙事新鲜。
5. Product Hunt 只作为发布周一站,不押注(2026 年 indie 淹没严重);同周铺 Uneed/Fazier。
6. **素材清单**(M6 任务卡):主 demo 视频、两张对比图(vs ComfyUI 开箱即用/vs 云平台价目表)、
   3-5 个单功能 GIF、双语 README(已有)、一键示例项目、无追踪脚本的秒开 landing。

## 2. M4「能力完整」——功能模块任务卡

> 全量任务卡(28 张,7 epic,行级核实)见
> [`superpowers/plans/2026-07-07-launch-features.md`](superpowers/plans/2026-07-07-launch-features.md)。
> 此处只列 epic 完整态与波次。

| Epic | 完整态一句 | 任务卡 |
|---|---|---|
| E1 Storyboard(核心差异化) | 粘贴脚本→shot 链;镜头参数传导;图/视频双直达;序列预览与导出同序 | SB-1~6 |
| E2 画廊 | 视频缩略/播/时长;筛选;存角色;发送画布;删除(文件+DB 同步收敛) | GA-1~7 |
| E3 聚合器 | 设置页可视化 CRUD+key 校验;≥2 协议模板;(二期)新增热生效 | AG-1~5 |
| E4 导出 | narrative 自动排序(主体已随 PR #143 合入 main;剩 EX-1′)+转码归一+进度取消 | EX-1′~3 |
| E5 角色进阶 | 视频生成自动带角色图;video inspector 角色区;角色库管理页 | CH-1~3 |
| E6 项目复制 | ⚠️ **裁决:排上线后**(BOARD 原判"单独立项";≡ backend BP-11,复用 LB-12 导入机器后
  成本减半)。features 的 PD-1~3 保留为**实现细化参考**,不进 M4 波次;若用户要提前,依赖 LB-12 | PD-1~3(细化) |
| E7 跨模块 metadata | duration/width/height/seed 回填 result 与 batch slot(**多 epic 阻塞点**) | XM-1~2 |

**波次**(波内并行、不同执行者不踩文件;冲突热区与硬依赖见明细;PR #143 已合入,EX-1′/SB-6 前置已解锁):
- Wave 1:**XM-1(最优先,三处下游)**、SB-1、SB-3、SB-5、AG-1、GA-1+2、CH-1
- Wave 2:XM-2(与 XM-1 同人)、SB-2、SB-4、GA-3、GA-4、AG-2、AG-3、EX-1′、CH-2
- Wave 3:SB-6、EX-2、EX-3、AG-4、AG-5、GA-5、GA-6、GA-7、CH-3

卡数口径:E1-E7 共 29 张(EX-1′ 为增量卡;PD-1~3 已移出 M4);规模 ≈ 2-3 个 sprint。
关键路径 = SB-5→SB-6/EX-1′(叙事闭环);XM-1→EX-3 为**弱**依赖(duration 缺失→indeterminate 进度,
不阻塞)。只能保一条先保 SB 线 + XM-1。**开 Wave 前先拍 §9 的 D-M4 系分叉**
(SB-1、GA-5/6、AG-4/5、EX-2 被阻塞)。

## 3. M5「能上生产」——后端/数据安全/性能任务卡

> 全量任务卡(LB-01~24 + BP-01~16 上线后系 + 24 行债表处置)见
> [`superpowers/plans/2026-07-07-launch-backend.md`](superpowers/plans/2026-07-07-launch-backend.md)。
> ⚠️ 前缀说明:backend 上线后卡已改用 **BP-xx** 前缀(原 PL-xx),与 UI 打磨卡 PL-1~8 区分。
> 与 UI 卡去重:LB-06≡GAP-3、LB-15≡GAP-2、LB-05 联动 GAP-8——同一工作只排一张;
> Inspector 测试欠账裁决为**上线前**(UI GAP-7 为准,backend 债 #19 让渡)。
> 严格复审新增三卡:**LB-22 备份还原路径 ✅ #189**(SCRAM 后用户无法手工 pg_restore——app 内还原入口,
> beta 前 M)、**LB-23 内存基线**(ImageCache 上限/长会话水位,S-M)、**LB-24 网络代理支持**
> (dio 不读系统代理,中文用户连不上海外模型商——`HTTPS_PROXY` env 先行 + 设置页代理区,上线前 M)。

**债表处置总账**:24 行 → 上线前必修 11、条件必修 1(build_runner,freezed 3.2.6 触发)、
上线后 9、永久接受 3(buildUpdate 白名单/InkWindowChrome/displayName 英文)。

**上线前硬门槛(数据安全)** — 进度 2026-07-17:**LB-07/09/10/11/12/13a/13b/14/15/17/18/22 全部 ✅**
——backend 上线前波次 W0-W4 收官;余下为条件项/上线后系:
- **LB-07 PG trust→SCRAM**:✅ #172(SCRAM-SHA-256 + 随机密码入 SecureStorage,存量 trust 零迁移)
- **LB-10 每日 pg_dump 冷备**:✅ #185(启动 post-frame 触发,-Fc tmp→rename 原子写,当日跳过,
  保留 7 份,PGPASSWORD 经 env,开发机无打包 PG 跳过;失败仅 warn 绝不阻断;恢复手册进 SETUP.md)
- **LB-11 项目导出**:✅ #188(zip=manifest+data.json+files/ 全保真——软删行含 deleted_at 一起带走
  保 FK 闭包,jobs 只带有 success slot 者+其全部 slot;`.partial`→rename 原子落盘;入口=项目卡菜单+
  getSaveLocation;顺带清债#20 characters/presets 真库 CRUD 集成测)
- **LB-12 项目导入**:✅ #192(**最大风险卡收官**——经三镜头设计评审 rev2:zip 安全门
  实测字节防 bomb+重名拒+保留名+UUID 段;全表重映射含 type_config.character_ids;
  files 先行 staging+rename 收崩溃窗口;单事务+补偿零残留;roundtrip 大红测=DoD;
  **BP-11 项目复制的全部机器就绪**)
- **真机验收补钉(2026-07-17)**:✅ #194——Windows `pg_ctl start` 管道继承挂死
  (postmaster 继承 Process.run 管道句柄,冷启动挂死至库进程落幕;打包版 Windows 首启即触发,
  Windows CI 排 pg 标签+控制器测试全 fake 故此前不可见);Windows 分支改 inheritStdio;
  随附 realpg 门控真栈 E2E(真 initdb SCRAM→pg_ctl→迁移→pg_dump→pg_restore 对换→teardown)
- **LB-13 purge 语义修正+孤儿文件回收**:✅ 切片 A(#163,purge 加 success-slot 守卫保画廊);
  ✅ 切片 B = **LB-13b**(#165,OrphanFileReaper DRY-RUN v1 只记不删;真删除待 dry-run 灰度后)
- **LB-14 崩溃遗留空 result 节点收敛**:✅ #162(启动 softDeleteEmptyOrphanResults);
  **LB-09 启动失败 surface**:✅ #169(PG 引导失败全屏错误替代白屏);
  **LB-17 全局错误钩子**:✅ #160(runZonedGuarded + crash 落盘)+ **LB-18 诊断包**:✅ #191
  (设置页两按钮;zip=info+logs/*含 pg.log+crashes/*+config 白名单;无 api_key 红测钉死)

**正确性簇**(LB-01/03/04/06 ✅ 已合入,LB-05 已消解——簇内清零):LB-01 状态常量化 ✅#156 → LB-03 JobQueue 拆分 ✅#159
(1168→504 行,竞态裁决留编排器 + `job_queue/` 四协作者)→ LB-04 乐观竞态 ✅#158(FIFO 串行队列,五控制器)
→ LB-05 已**消解**(#164 退役 JobQueuePanel,卡面自动消解条款触发)/LB-06 ✅#166(5 站点 error 横幅收口)。

**波次**:W0(S 簇:LB-01/02/05/08/19 + 第 0 天启动 LB-20 资源置备与 LB-21 盯 freezed)→
W1(LB-03/04/06/17)→ W2(LB-07/09/13/14/16)→ W3(LB-10/11/15/18)→ W4(LB-12 压轴)。
体量 ≈ 22-28 人日。关键路径:LB-08→07→10(备份链✅收尾)、LB-11→12(导入链)、LB-20(日历时间)。

**新增卡(D-10 拍板后,2026-07-09)**:**DIR-1 数据目录迁移**(M)✅ **#183 已合**——AppPaths 从 `~/InkFrame` 迁平台
惯例路径(Win `%LOCALAPPDATA%\InkFrame`、macOS `~/Library/Application Support/InkFrame`);存量目录
启动时一次性迁移(检测旧址→原子搬移/失败回退,对齐 ADR-0012 前向语义);SETUP/PKG-5/README 路径全改。
**依赖:无;是 LB-10(冷备路径)的前置——LB-10 已解锁**。验收三条(新装落新址、存量升级数据无损、
旧址留迁移标记)均随 #183 落地;对抗评审 P1(fallback 根/marker-only 组合链)已堵,单实例守卫缺口记 BOARD 债表。

## 4. M5「能上生产」——UI/UX 完整性任务卡

> 全量任务卡见 [`superpowers/plans/2026-07-07-launch-ui-ux.md`](superpowers/plans/2026-07-07-launch-ui-ux.md)
>(含逐屏现状核实 19 条结论)。此处只列索引与排序。

**上线前必做**(按序):
1. **CV-1 死件清理**(S)✅ **#174 已合**(D-7 裁撤案:左工具栏/顶栏 ▶/avatar/footer 死件裁撤,
   footer settings 接真跳设置页)——原发现:死按钮=坏承诺,先做腾出界面真相。
2. **ON-1 首启向导**(L)✅ + **ON-2 示例项目入口**(S)✅ **#175 已合**（2026-07-17 核验回填：
   语言→Key→起步三步向导 + createSample 三入口=向导/Studio 空态/画布空态,测试俱全;
   BOARD 近期落地表此前漏登 #175）。**ON-2b 示例演示内容**:✅ #195
   (createSample 单事务种子化——示例泳道+预填 prompt 的 image config 节点,
   纯本地零生成;SampleSeed 经 ARB 三入口传入,控制器不触 l10n)。
3. **GAP-8 渲染队列取消入口**(M)✅ **已随 #164 合入**(取消入口+最近失败区,顺带退役 JobQueuePanel 清 P1-x2 债)——原发现:后端 cancel 链路+测试全齐但 UI 不可达,
   用户烧真钱的任务无法取消;顺带处置未挂载的 JobQueuePanel(挂或删,删则 P1-x2 债自动清)。
4. **PL-4a 删除防误伤垫层**(S)✅ **#168 已合**(节点/连线删除 Deleted·Undo)。
   **PL-4b 通用 undo/redo(XL)明确排上线后**,前置=BOARD 行 87 并发债。
5. **PL-2 快捷键第一批**(M)✅ **#176 已合**(Delete/Esc/⌘A/⌘±0)+ **PL-1 ⌘K 做真**(D-8 拍 A)✅ **#174 已合**(≤6 上下文动作)。
6. **GAP-3 AsyncValue error 态统一**(M,新共享件 InkAsyncSlot;清单含复审补充的
   library_sidebar:45 与 canvas_view 裸 toString 站点;LB-06/#166 已合,余量归本卡)+ **GAP-4 slot error 文案**(S)
   ✅ **#167 已合**(Tooltip + danger 文案)。
7. **GAP-1 设置页 Custom Provider 编辑 UI**(L)✅ **#200 已合**(Store 写侧 raw
   保真+损坏拒写+原子写;校验纯函数双端共用;列表+表单+删除确认+重启生效常驻条;
   API Keys custom:* displayName 顺带修——"重启生效"边界守住,不碰 registry 变异)。
8. **GAP-2 软删项目回收站 UI**(M)✅ **#190 已合**(≡LB-15：sidebar 真回收站入口取代 ARCHIVE 死行、
   管理画布已删区;首版无永久删除)。
9. **PL-6 窗口状态记忆**(S–M)✅ **#170 已合**(退出捕获+启动恢复+多显示器 clamp)。
10. **ON-3 ffmpeg 引导**(S–M)✅ **#196 已合**(设置页 About 区探测行:找到=路径/
    未找到=平台化指引 winget/brew+INKFRAME_FFMPEG,复用 exportVideoFfmpegMissing 防双源)。
    **ON-4/i18n pass**(S)✅ **#197 已合**(三轴并行审读:错误文案归因+下一步动作、
    术语统一、省略号统一、canvasNodeType* 6 僵尸键清除)。
    **GAP-7 + ON-5**(质量闸)✅ **#198 已合**(Inspector 预设/成本断言收债;
    五屏空态 golden 入 CI,ubuntu 铸线)——第 10 条收官。
    **GAP-3 余量**✅ **#199 已合**(24 站点审计:泳道方向读错并入横幅链;raw toString
    上屏收敛,探测诊断行有意例外;base style 读错中止防空覆盖;InkAsyncSlot 判
    YAGNI——第 6 条关闭)。
    **第 7 条 GAP-1**✅ #200——**上线前必做 1-10 全部落地**(2026-07-18 逐条核对:
    1 CV-1/#174,2 ON-1+2/#175+#195,3 GAP-8/#164,4 PL-4a/#168,5 PL-2+PL-1/#176+#174,
    6 GAP-3/#166+#199,7 GAP-1/#200,8 GAP-4/#167,9 PL-6/#170,10 ON-3/4/GAP-7/ON-5
    /#196+#197+#198)。

**上线后首迭代起**:PL-4b undo 栈、CV-4 左工具栏实装/CV-5 视口 chrome(zoom 指示+fit,minimap 后置)、
CV-2/CV-3(节点色条/Inspector 浮动,拍板后随时)、PL-3 右键菜单(建议尽早)、PL-5 框选群拖、
PL-7 焦点环、PL-8 文件拖入(与画廊拖入统一设计)。
**让渡声明**:画廊视频缩略图/播放 ≡ features **GA-1+GA-2**(M4 Wave 1,技术路线以 GA 为准:
读已落库 thumbnail_url,非现场抽帧);narrative 自动排序 ≡ features **EX-1′**(GAP-5/GAP-6 仅指针)。

**排序修正(复审)**:CV-1 虽是纯减法,但有一道门——D-7 的 d4/d5/d6 拍板(原第二道门 PR #143
已合入,canvas_top_chrome 冲突源已消)。实际首发顺序:拍板 → CV-1。
UI 文档内 BOARD 行号引用一律以**文字锚**为准(本 PR 自己给 BOARD 加了两行,行号已位移)。

**重要澄清**:画布 UI 方向**不存在五选一**——mockups 索引明标 Selected: V1 Amber Noir,代码就是它;
真正的决策是 V1 spec 保真度收口的 7 个子项(见 §9 D-7),勿再开选型会。

## 5. M5/M6——发布工程任务卡

> 全量任务卡与 alpha.10 SOP 见
> [`superpowers/plans/2026-07-07-launch-release-engineering.md`](superpowers/plans/2026-07-07-launch-release-engineering.md);
> 调研支撑见 [`research/2026-07-07-release-engineering.md`](research/2026-07-07-release-engineering.md)。

**现状要害**(2026-07-18 更新):release.yml 已随 alpha.10 首跑成功(双平台 build+publish 一次通过,
macOS arm64 zip/dmg + Windows x64 zip,均 unsigned);**PG 分发源已解**(PKG-2A 方案 A 上游直拉,
零 variable 配置,下个 tag 起产物含嵌入式 PG——Windows 侧本机真栈已验,mac 侧待 release CI
首跑验证;checksums.txt 亦随之落地);仍欠:alpha.6 仍错挂
"Latest"(alpha.2–.6 prerelease=false 未 PATCH)、release notes 双重生成致重复+基线错(#66 起);
good-first-issue 池为 0。

**模型侧可立即并行、零用户依赖**:PKG-1 流水线首演练(✅ 已随 alpha.10 以真实 tag 实质完成,
notes 双重生成问题随 PKG-6 收口)、PKG-2A PG 上游直拉 ✅ 本 PR(EDB zip SHA 锁定裁剪+
brew relocate,release.yml 无条件 fetch;mac 侧待 release CI 首跑验证)、
PKG-5 安装文档(S,复审补充:Defender/EDR 排除段、卸载与数据、迁移新机 SOP、零遥测承诺句)、
PKG-6 Release 卫生(XS)、QG-1 回归清单 v2(S)、QG-6 checksums+清单落地(S,checksums.txt
已随 PKG-2A 落,余 BUILD-RELEASE §9 分层)、
UPD-1 应用内检查更新 ✅ #173(零新增依赖,ProcessRunner 开系统浏览器)、WEB-1 Pages 官网(M,FAQ 补
「为什么没有 Linux」)、WEB-2 示例模板(M)、COM-1 gfi 池重建(S,候选与 backend W0/W1 卡
双占用需协调)、COM-2 Issue 模板+SECURITY.md scope 对账(XS)、COM-3 CONTRIBUTING 英文摘要(S)。
(QG-4 升级演练从本清单**移除**——依赖 D-4/U7 拍板,非零用户依赖。)

**复审新增卡(见 release 明细)**:**LEG-1 第三方许可聚合**(M,⚠️ libmpv LGPL 义务已随 alpha.9
分发触发——核实 media_kit 构建变体、建 NOTICE/THIRD-PARTY、关于区许可入口、字体 OFL 文本);
**PKG-8 winget manifest**(S,依赖签名)、**PKG-9 Homebrew cask**(S,含 depends_on ffmpeg);
**AST-1~3 上线素材制作**(demo 视频依赖 SB-6/EX-3/WEB-2;HN 答辩稿+karma 前置=日历时间项);
QG-2 矩阵加 **CJK 用户名 VM** 一列(中文用户首启失败头号现场);
beta 准入追加第 9 条:**第三方许可 NOTICE 上线**。用户必办追加 **U11**(HN 账号 karma 预热)、
**U12**(B站/小红书账号,若走中文渠道)。

**用户必办**(U1-U10 全表见明细文档;三条互不阻塞的关键路径):
- **U1** Apple Developer($99/年)+ 证书 6 值进 Secrets → 解锁 macOS 签名公证
  ⏸️ **已拍推迟(2026-07-09):暂不购买**——开发/alpha 期继续 unsigned 分发;beta 冲量前优先补 U1(mac 主平台)
- **U2** Windows 证书拍板(OV ~$100-200/年 / Certum 开源 €69 首年;Azure 中国个人不可用)
  ⏸️ **已拍推迟(2026-07-09):暂不购买**——推荐档=Certum 开源证书;可后于 U1,极端情况 beta 期 Win 继续
  unsigned+安装文档说明 SmartScreen 绕行,1.0 前补。**beta.1 准入的签名两条(第 2/3 条)执行顺延至补购后**
- **U7** 数据升级政策拍板(→ D-4,牵动铁律文本与 SCRAM 覆盖面)
- alpha.10 已按"不等 U1/U2"路线发出(release.yml 产 unsigned 双平台产物);
  **beta.1 被 U1+U2+QG-4 升级演练硬阻塞**(D-4 已拍 ADR-0012、UPD-1 已随 #173、
  PG 分发源已随 PKG-2A 交付,均从阻塞名单移除)。

## 6. 模型接入路线(2026-07 调研,全表与来源见 [`research/2026-07-07-model-landscape.md`](research/2026-07-07-model-landscape.md))

> MOD 系为方向卡(一行制):**开工前须按附录模板扩成完整任务卡**(做法/验收/依赖);
> P0=M4 窗口内完成(gpt-image-1 有死线),P1=beta 前后,P2=1.0 前后评估。

**P0(上线前,全部是现有 provider 的模型 ID/任务类型升级,零新协议)**
- MOD-1 OpenAI 升级 gpt-image-1.5/2——**gpt-image-1 于 2026-10-23 弃用,有死线**(S;
  现值 gpt-image-1 已核实)。
- MOD-2 从一切规划移除 Sora——API 2026-09-24 关停,无后继(0)。
- MOD-3 Gemini 升级 Nano Banana 2/Pro + 多参考图(≤14 张,5 人角色一致性——分镜第一刚需)(M;
  现值 gemini-2.5-flash-image-preview 已核实)。
- MOD-4 Wanx **补「视频续写」任务类型**(S-M)——复审勘正:四件已全在 wan2.7、首尾帧/r2v 均已实现,
  调研的"升级模型 ID"项不成立,勿重复立项。
- MOD-5 Kling 3.0 Turbo 变体(S)——⚠️ 现有 provider 走 **DashScope 渠道**非 kling.ai 官方 API;
  Turbo/Motion Control 可行性取决于 DashScope 上架,否则等于新开官方 API provider(ROADMAP 已有
  该 Open 项)。Motion Control 3.0:P2 观察,渠道上架再评估。

**P1(上线后第一批)**
- MOD-6 Veo 3.1(含 Lite):首尾帧+3 参考图+extend+原生音频,能力矩阵最贴分镜;复用 Gemini key 生态(L)。
- MOD-7 OpenRouter 图像模板:验证 `/api/v1/images` 与现有模板匹配(模板需支持**可配端点路径**),
  一个模板解锁 30+ 模型(M);Recraft 已验证 OpenAI 兼容,零代码写入「已验证端点」文档(XS)。
- MOD-8 自定义模板扩展参考图输入(`/images/edits`/多图)——现有模板仅 t2i、maxRefImages=0(M)。

**P1(续)**:Seedream/Seedance 经 OpenRouter/模板接入(调研定级 P1——性价比与多参考能力第一梯队;
原稿误归 P2,已对齐),量大再原生 Volcano Ark。
**P2**:OpenRouter 视频模板(优先)或 fal 队列模板;Vidu Q3 经阿里百炼通道验证(复用 DashScope)。

**能力趋势对产品的含义**(功能规划输入):multi-shot 单节点产出"一场戏"、音频开关/音轨概念、
参考类型体系(角色/道具/场景/风格/音色)、视频延长"接着拍"——纳入 M4 各 epic 设计考量。

## 7. 里程碑准入清单(Definition of Done)

**M4「能力完整」出口**:§2 表中各 epic 的"完整态定义"达成(E6 项目复制除外,已裁决上线后);
M4 期间可随时发 alpha tag。
**M5「能上生产」出口 = beta.1 准入**(发布工程 8+1 条,详见明细文档):双平台含 PG 安装物 ✓ /
macOS 签名公证 ✓ / Windows 签名产物 ✓ / 应用内检查更新 ✓ / 数据政策拍板+升级演练 ✓ /
回归清单双平台一轮 ✓ / 安装文档上线 ✓ / 导出 UI+画廊可用 ✓ / **第三方许可 NOTICE 上线 ✓(复审补)**。
**M6「公开上线」出口**:官网可访问 + 素材三件套(AST 系)就绪 + 冷启动首发(§1.4 渠道 1-2)执行完毕。
**1.0**:script→storyboard→generate→export 贯通;undo/redo;软删恢复 UI;检查更新稳定 ≥1 beta 周期;
日志一键打包;真机帧率基线达标;**Windows 签名信誉建立;发布节奏公开**;无 P0/P1 open bug;
beta 全周期零数据事故;官网稳定;SLA 演练过一次。

## 8. 远期(1.0 后,不排卡只记方向)

- **叙事纵深**:LLM 辅助脚本拆分(D-M4-1 C 档,依赖 chat 协议模板)、多镜头一致性编排
  (调研趋势 #1:multi-shot 模型一个节点产出一场戏)、音轨/对口型概念进节点模型、
  视频延长"接着拍"(Veo extend/wan2.7 续写)、参考类型体系(角色/道具/场景/风格/音色)。
- **画布纵深**:通用 undo/redo(PL-4b,前置=并发模型债)、框选群拖、minimap、
  文件/画廊真拖拽(desktop_drop)、序列时间线视图(分镜→粗剪的过渡形态)。
- **生态**:更多协议模板与聚合器(fal 队列模板/OpenRouter 视频)、本地模型 provider
  (ComfyUI/本地推理桥)、模板/预设分享格式。
- **工程**:updates.json 真自动更新(UPD-2)、macOS x64/universal、崩溃报告 opt-in
  (Aptabase 路线)、团队版探索(InvokeAI $19/$49 模式)。
- **运营**:官网从单页扩文档站、第三语言、Discord(Discussions 周活跃 >10 帖再评估)。

## 9. 决策区(需用户拍板,格式:选项+推荐;拍板后记 BOARD 并解锁对应卡)

**决策→阻塞→最晚拍板点速查**:

| 决策 | 阻塞 | 最晚拍板点 |
|---|---|---|
| D-2 许可证 / D-3 商业承诺 / D-1 口号 | README/官网/公告措辞 | M6 素材制作前 |
| D-4 数据升级政策(=U7) ✅ **已拍→ADR-0012** | QG-4/5、SCRAM 覆盖面、**每个 schema PR**、LB-12 manifest 策略 | ~~下一个 schema 变更前~~ 2026-07-08 拍板 |
| D-5 Win 安装物(=U6)/ D-6 Win 证书(=U2) | PKG-4、beta 准入 | PKG-4 实测后即拍 |
| D-7 画布保真度 d4-d7 / D-8 ⌘K ✅ **已拍(2026-07-09)** | ~~CV-1~~ 已解锁 | ~~CV-1 开工前~~ 已拍板 |
| D-M4-1~8 | GA-5/6、AG-4/5、EX-2、SB-1、CH-3 | M4 对应 Wave 开工前 |
| D-BE-1/2 | LB-13A、LB-11/12 | 对应卡开工前 |
| D-9 任务状态载体 / D-10 数据目录选址 ✅ **D-10 已拍(2026-07-09)** | 规划运维 / ~~LB-10~~ 已解锁(新增迁移卡) | 首个 M4/M5 卡完成前 / ~~LB-10 前~~ 已拍板 |

- **D-1 主口号与定位措辞**:A. storyboard-first 新口号(推荐,见 §1.2)/ B. 维持现口号。
- **D-2 开源许可证**:⚠️ **现状=仓库已以 MIT 公开发布**(LICENSE 文件 + README badge,alpha.9 有
  公开分发物)——已发布版本的 MIT 授权不可撤回,既有 clone/fork 永久保留 MIT 权利;变更只对未来
  版本有效,且需外部贡献者(如有)同意,社区观感风险("rug pull" 指控)正撞冷启动叙事。
  选项:A. **维持 MIT**(推荐——摩擦最小,与 BYO-key 社区定位相容;"防白嫖"对存量代码本就达不成)/
  B. 未来版本转 Apache 2.0(增加专利条款,迁移成本低)/ C. 未来版本转 AGPL(防云厂商,
  但保护不了已 MIT 化的全部存量,且观感成本最高)。**上线前拍**。
- **D-3 商业模式承诺**:A. 个人永久全功能免费 + 远期团队版(推荐)/ B. 全免费+捐赠。
  决定 README/官网的承诺措辞,一旦公开难收回。
- **D-4 数据升级政策(=QG-5,牵动铁律文本)** ✅ **已拍(2026-07-08):选 A → [ADR-0012](adr/0012-forward-migration-as-sole-data-upgrade-path.md)**。
  单线前向迁移是用户数据唯一升级路径;禁降级/旧格式并行/僵尸 API,但用户数据必须存活、不删库、已发布迁移不可变。
  已同步 `docs/CLAUDE.md` / `CONTRIBUTING.md` / `EXECUTION-PLAYBOOK.md` 不变量 #11 铁律文本;解锁 LB-07/LB-12/QG-4。
  原选项留档:A(已选). 迁移链转正(勘正:alpha.9 分发的是机制、schema 停在 v2,链现已到 v7)/ B. 字面零兼容
  (公开测试期不可接受)/ C. alpha 期 B、beta.1 起 A(复审否决:alpha.9 公开分发+零遥测即关闭 B 窗口,无安全重基线期)。
- **D-5 Windows 安装物形态**:A. 先 MSIX 实测(容器化 vs 内嵌 PG 兼容性存疑)/ B. Inno Setup /
  C. 先 zip 兜底。建议看 PKG-4 实测结果再定。
- **D-6 Windows 证书路径**:A. OV 软证书(~$100-200/年,脚本即用)/ B. Certum 开源证书
  (€69 首年,限个人+开源)/ C. Azure Artifact Signing(**中国个人不可用**,需组织实体)。
- **D-7 画布 V1 spec 保真度收口** ✅ **d4/d5/d6 已拍(2026-07-09):裁撤优先**——d4=B(左工具栏裁到
  只留有功能的)/ d5=▶与 avatar 裁、⌘K 保留做真(联动 D-8)/ d6=footer settings 接真跳设置页、
  archive/people/trash 裁(ARCHIVE 随 GAP-2 激活再回)。**CV-1 已交付**(#174 合入 main)。
  d1(Inspector 形态)/d2(色条)/d3(camera)/d7(text 节点)不卡 CV-1,后拍。
- **D-8 ⌘K 命令面板** ✅ **已拍(2026-07-09):A 做真**(首版 ≤6 动作;已随 #174 交付 PL-1)。

**功能模块系(D-M4-1~8,详见 features 明细文档;开 M4 Wave 前拍)**:
- **D-M4-1 脚本拆分**:A 规则拆分(推荐)/ B LLM / C A 先行后加 AI 按钮。
- **D-M4-2 画廊→画布形态**:A 菜单动作(推荐)/ B 画布内抽屉真拖拽(后续)/ C OS 拖放。
- **D-M4-3 画廊删除语义**:A 永久删除 行+文件(推荐)/ B 仅隐藏 / C 软删保文件。
- **D-M4-4 聚合器生效时机**:A 编辑+重启(推荐先做)→ B 追加运行时新增 / C 全运行时(永不)。
- **D-M4-5 第二协议模板**:A openai-chat-image(推荐)/ B gemini-compatible / C 延后。
- **D-M4-6 导出转码档位**:A 单开关 1080/30fps/H.264/丢音频(推荐)/ B 有音轨则 copy / C 参数面板。
- **D-M4-7 项目复制取舍**:A 不复制 jobs/batch/exports(推荐)/ B 复制终态(+M)。
- **D-M4-8 角色库入口**:A 独立整屏仿 Gallery(推荐)/ B Gallery tab / C 设置页(不建议)。

**后端系(D-BE,详见 backend 明细)**:
- **D-BE-1 purge retention 语义**:✅ **已拍 A**(LB-13a/#163 落地:有 success slot 的 job 永不 purge,保画廊)。
- **D-BE-2 项目导入是否携带 jobs** ✅ **已拍(2026-07-09):A 仅携带拥有 success slot 的终态 jobs**
  (导入后画廊完整可见;LB-11 卡面按 A 写就零改动)。**LB-11/12 导入链已解锁**。

**新增(严格复审补充)**:
- **D-9 任务状态载体**:A. markdown 勾选(BOARD+MASTERPLAN,现状)(推荐起步)/
  B. GitHub Projects/issue 化(100+ 卡可视化好,维护重)。
- **D-10 数据目录选址** ✅ **已拍(2026-07-09):B 迁平台惯例路径**——Windows `%LOCALAPPDATA%\InkFrame`、
  macOS `~/Library/Application Support/InkFrame`(降杀软误报面)。**LB-10 冷备路径已解锁**。
  ✅ 追踪卡 **DIR-1 数据目录迁移已交付(#183)**(见 §3 末):AppPaths 改造 + 存量 `~/InkFrame` 一次性迁移
  (前向迁移语义,对齐 ADR-0012)+ PKG-5/SETUP 文档全改;**LB-10 备份路径按新址实现,DIR-1 是其前置**。
  PKG-5 仍要写 Defender 排除建议(路径迁移只是降误报面,不是消除)。

## 10. 文档地图

| 文档 | 内容 |
|---|---|
| [`EXECUTION-PLAYBOOK.md`](EXECUTION-PLAYBOOK.md) | **先读**:开发流水线/工具链地雷/架构不变量/缺陷模式 |
| [`research/2026-07-07-market-landscape.md`](research/2026-07-07-market-landscape.md) | 竞品全表/分发模式/冷启动 playbook/定位验证(含来源) |
| [`research/2026-07-07-model-landscape.md`](research/2026-07-07-model-landscape.md) | 图像/视频模型 API 全表/聚合器/能力趋势(含来源) |
| [`research/2026-07-07-release-engineering.md`](research/2026-07-07-release-engineering.md) | 签名公证/更新/ffmpeg 合规/遥测/内嵌 PG 调研(含来源) |
| [`superpowers/plans/2026-07-07-launch-ui-ux.md`](superpowers/plans/2026-07-07-launch-ui-ux.md) | UI/UX 全量任务卡(ON/GAP/CV/PL 系) |
| [`superpowers/plans/2026-07-07-launch-release-engineering.md`](superpowers/plans/2026-07-07-launch-release-engineering.md) | 发布工程全量任务卡(PKG/UPD/QG/WEB/COM 系)+ alpha.10 SOP + U1-U10 |
| [`superpowers/plans/2026-07-07-launch-backend.md`](superpowers/plans/2026-07-07-launch-backend.md) | 后端/数据安全任务卡(LB-xx 上线前 / BP-xx 上线后) |
| [`superpowers/plans/2026-07-07-launch-features.md`](superpowers/plans/2026-07-07-launch-features.md) | 功能 epic 任务卡(SB/GA/AG/EX/CH/PD/XM 系) |

> ⚠️ 前缀警示:UI 打磨卡 **PL-1~8** 与 backend 上线后卡 **BP-01~16**(原 PL-xx,已改名)无关;
> 引用任务卡一律带文档名。规模刻度全集:XS<2h / S≈半天 / M≈0.5-2天 / L≈2-5天 / XL≈1周+。
> 4 份明细 plan = **冻结于 2026-07-07 的开工快照**:开卡前先按当前 main 复核 file:line,
> 完成状态只记 BOARD/MASTERPLAN,不回写明细。

---

## 附:任务卡模板

```
### <ID> <标题>(规模 S/M/L/XL)
为什么:<一句用户/工程价值>
涉及:<精确文件/系统>
怎么做:<3-8 步,引用既有模式与 PLAYBOOK 章节>
验收:<可执行标准,含测试与文档同步>
依赖:<卡 ID / 决策 D-x / 用户侧动作>
风险:<一句>
```
