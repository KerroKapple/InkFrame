# InkFrame 活看板（单一事实源）

> 这是"当前在做什么、做到哪"的唯一速查表。**接下来做什么**(到 1.0 的全部任务卡与决策项)见
> [`MASTERPLAN.md`](MASTERPLAN.md);**怎么做不踩坑**见 [`EXECUTION-PLAYBOOK.md`](EXECUTION-PLAYBOOK.md)。
> 背景分析/行业借鉴见
> [`STATUS-AND-ROADMAP-2026-06-30.md`](STATUS-AND-ROADMAP-2026-06-30.md)（快照，2026-06-30）。
> 旧的散落文档（PROGRESS / ARCHITECTURE-SURVEY / AUDIT-REPORT / PROGRESS-VERIFICATION /
> ROAD-TO-BETA）视为**归档快照**，不再更新；状态以本表为准。
>
> 状态图例：✅ 完成 · 🔵 进行中 · ⬜ 未开始 · 🅿️ 已延后（附因）
> 最近更新：2026-08-05 · 最新发布：**v0.1.0-alpha.11**（2026-07-22,首个含嵌入式 PG 的双平台产物;
> PKG-2A release CI 首跑绿,产物体积增量与 PG 二进制吻合（mac 39.6→68MB / win 36.7→71MB）;
> 干净机实机验收待做;待签名 U1/U2 方为干净机免绕行可装）

## M1 —「能用起来」✅ 完成（已随 PR #133 合入 main）

| 功能 | 状态 | 证据 |
|---|---|---|
| 构建解封（重生 freezed + l10n + 修 import） | ✅ | 本地编译/analyze 干净 |
| 偏好持久化（主题/语言/对比度/缩放，重启不丢） | ✅ | `7dfcad6` + 测试 |
| 节点级实时进度 + 高级图像参数（宽高比/负向/种子/批量） | ✅ | `cd61520` + 测试 |
| 画布丝滑（改选中只重建涉及卡片） | ✅ | `b78a608` + 测试 |
| Provider 下拉直读 const（不实例化 9 provider） | ✅ | `a34fb2d` + 测试 |
| 项目重命名 + 删除（软删可恢复） | ✅ | `af5bde6` + 测试 |
| 画布 P0/P1 正确性簇（标题/JobQueue/边守卫/hash/泳道事务） | ✅ | `fe3c6c4`..`1073433` |

## M2 —「创作者要的」✅ 完成（2026-07-02，CI 全绿收官）

> 主体已随 PR #134 合入 main；参考图/首尾帧 UI 收尾（B1–B3 + 连线智能默认 role）随 PR #138 合入。
> 表中 hash 均为 main 主线提交。

| 功能 | 状态 | 优先级 | 备注 |
|---|---|---|---|
| 参考图 / 首尾帧 UI（Provider 已支持，缺界面） | ✅ | P0 | 共享 `NodeInputsSection`（image+video 均挂载，缩略图/role 按 `supportsFirstFrame/LastFrame` 门控/n-max 计数）；连线经画布 link 模式，image→video 智能默认 first_frame（PR #138 B1/B3） |
| 角色一致性（项目级角色参考，自动带入生成） | ✅ | P0 | characters 表/仓储/资产服务 + 生成按能力注入 + Inspector 角色区/存为角色（`528a3e9`/`eda2d7c`）。仅 image 节点、maxRefImages>0 且 imageToImage 生效 |
| 批量 / 变体（生产侧 + 消费侧全链路） | ✅ | P1 | 消费侧骨架（`854124b`）+ 生产侧：提交事务预建 slot 占位、JobQueue 逐 slot 落库、结果节点 Inspector 挂 `BatchResultsGrid`、取消/失败/孤儿收敛。拍板语义：≥1 成即 job success、取消保留已成 slot。经 3 路对抗评审,2×P1+4×P2 全修 |
| 提示词模板 / 预设库 | ✅ | P1 | 项目级 schema_v7 预设库 + Inspector 点选应用/存为预设（`8a28777`） |
| 成本估算 UI（CostModel 已定义，缺消费端） | ✅ | P2 | `estimateCostUsd` + 图像/视频 Inspector 实时预估（`1273522`/`d1dfc46`） |
| 视频 Inspector 接成本 | ✅ | P2 | `d1dfc46`。角色注入自 Polish Wave 1 CH-1 起覆盖视频（原 v1 仅图像）；视频首/尾帧语义已接通——video inspector 挂入边区 + role 切换，控制器建行前校验帧能力位不支持即显式拒绝（PR #138 B1/B2） |
| 文件系统导入参考图（file_selector） | ✅ | P2 | Characters 区「从文件导入」（`94e18ab`）。桌面需开发者模式，与 media_kit 同 |
| CI 烟测 + golden 首跑绿（beta DoD） | ✅ | P1 | run 28595968123 全绿（analyze/test+coverage 70% 闸/golden/secret-scan）。唯一 CI 红为 ME-31 测试自朽（坏迁移 v6 与真实链重号被跳过），已动态化修复 `5d519b7` |

## M3 —「差异化」🔵 起步（骨架设计见 `docs/M3-SKELETON.md`）

| 功能 | 状态 | 备注 |
|---|---|---|
| 分镜 / Shot 节点（脚本→分镜→序列） | 🔵 | Shot 编辑器落地（`3ba33d3`）；**首切片完成**：「用本镜备注生成图像」（shot_notes→image config 节点+narrative 边）+ FAB/空态 shot 创建入口 + addNode typeConfig 透传。后续：脚本解析、镜头级参数、序列预览 |
| 视频导出 / 拼接 | 🔵 | **服务层落地**：`VideoExportService.concat`（项目相对路径进出）→ `FfmpegVideoExportService`（concat demuxer 流拷贝 `-c copy`，不转码，要求输入同编码参数）+ `FfmpegLocator`（INKFRAME_FFMPEG env → PATH 探测，命中缓存）+ 最小 `ProcessRunner` 抽象（fake 可注入）；`FileResolverService.resolveInProject`（项目根边界安全校验，导出落 `exports/`）。**不打包 ffmpeg 二进制**（体积/许可评估延后）：系统有 ffmpeg 才真拼接，没有 → `LocalIOError(reason=ffmpeg_not_found)`。真 ffmpeg 集成测 `@Tags(['ffmpeg'])` TEST_FFMPEG=1 门控。**UI 入口落地**：`features/export`——画布顶栏「导出视频」按钮（无 video result 时禁用+说明 tooltip）→ 导出对话框（按 position.x 升序默认全选、复选/上下移手动排序、输出名本地预校验同 `_assertPlainFileName` 规则、busy 态 indeterminate、成功 snackbar+复制绝对路径、ffmpeg_not_found 专门文案 `exportVideoFfmpegMissing`）；`ExportController` 承担画布相对→项目相对路径换算（补 `canvases/<canvasId>/` 前缀）。后续：narrative 链自动排序、转码/分辨率归一、打包二进制评估 |
| 本地素材 / 产物画廊（借鉴 InvokeAI） | 🔵 | **首切片落地**：`features/gallery`——project 维度只读聚合（result 节点 image_url/video_url + batch_results 成功 slot，`listSuccessByProject` 一次跨画布查询 + 与节点主图同路径去重，createdAt 倒序）→ 网格 UI（图片 tile 走 fileResolver + 图片 lightbox；视频 tile 图标+时长占位）；入口=Studio 项目卡菜单「Gallery」，路由走 `currentGalleryProjectProvider`（同 canvasId 语义）。**视频缩略图/播放（GA-1/2/7,PR-3 #208）与筛选/搜索+存为角色（GA-3/4,PR-4）已随 Polish Wave 1 落地**；后续：拖入画布（GA-5,D-M4-2 待拍板）、删除（GA-6,D-M4-3 待拍板）；视频时长已全链路打通（#177 写侧 + XM-1b 存量启动回填）；fake `listSuccessByProject` join 派生列由种子行提供（契约见注释，PG 集成测兜真语义） |
| 模型扩展（自定义 Provider，BYO-key） | 🔵 | **首切片落地**：`custom_providers.json`（逐条校验 + 损坏兜底）→ 协议模板 `openai-image` 派生 capabilities → `OpenAICompatibleImageProvider`(extends SyncProviderBase) → 启动期一次性注册（改 json 重启生效）；key 复用 `provider.custom:<id>.api_key`，设置页/门控/banner 零改动生效。PROVIDER-API §13 已重写为唯一方案，ADR-0009 已修订（2026-07-02）。后续：设置页编辑 UI、运行时增删（registry 变异非 invalidate）、更多协议模板 |
| 定位落地（README/官网：你的数据/Key/工作室） | 🔵 | README 一翼已随 PR #136 落地：双语 README + 真实画布截图/生成 GIF，文案即 local-first/your disk/OS Keychain；官网未动 |

## 近期落地（非里程碑）

| 事项 | PR / commit |
|---|---|
| 内嵌 PostgreSQL 装进 app bundle（macOS+Windows，发布线首件） | #135 |
| 双语 README + 定位文案 | #136 |
| wanx-i2v 对齐 wan2.7 服务端契约（`input.media` 数组；旧 `img_url` 被拒致 i2v 全线 400）+ macOS 标题栏平台惯例 | #137 |
| 参考图/首尾帧 UI 收尾（B1–B3）+ 连线智能默认 role；i2v media×fail-fast 语义整合 | #138 |
| 快修簇：暗色 on-color 对比度（colorScheme+InkButton）/ base64 守卫统一 / 捕获收窄 / 吞错补提示 / 僵尸清理 | #140 |
| M1 补遗四项落地（见下表） | #141 |
| 孤儿任务补写 completed_at 堵 retention 漏洞 + studio 裸 catch 收窄 | #149 |
| light 变体 on-color 对比度回归修复 + WCAG 对比率三层锁定测试（新增 onAccent/onDanger 语义 token） | #151 |
| 审计收口差量：D-1/D-4 文档执行 + ADR 修订记录×5 + LB-01~17 回填 | #150 |
| Debug+macOS 文件型密钥存储绕 Keychain -34018（dev-only，本地真实生成解锁） | #148 |
| GAP-8 渲染队列取消入口 + 最近失败区，退役 JobQueuePanel（清 P1-x2 债） | #164 |
| **D-7(d4-d6 裁撤优先)/D-8(⌘K 做真)/D-BE-2(A 携带终态 jobs)/D-10(B 迁平台惯例路径) 四决策拍板** | 2026-07-09，详见 MASTERPLAN §9 |
| GAP-4 batch slot 失败可读化（Tooltip + danger 文案） | #167 |
| PL-4a 删除防误伤垫层（节点/连线删除 Deleted·Undo） | #168 |
| LB-09 启动失败 surface（PG 引导失败全屏错误替代白屏） | #169 |
| PL-6 窗口状态记忆（退出捕获+启动恢复+多显示器 clamp） | #170 |
| LB-13b OrphanFileReaper 磁盘孤儿 GC DRY-RUN v1 | #165 |
| LB-06 AsyncValue error 态收口（加载失败不再静默吞成空白，5 站点 error 横幅） | #166 |
| LB-07 嵌入式 PG trust→SCRAM-SHA-256（新集群随机密码入 SecureStorage，存量 trust 零迁移） | #172 |
| UPD-1 应用内检查更新（releases 列表自比 SemVer 最大版，设置页入口；零新增依赖） | #173 |
| CV-1 死件清理（D-7 裁撤案）+ PL-1 ⌘K 命令面板做真（D-8，≤6 上下文动作） | #174 |
| ON-1 首启三步向导（语言→Key→起步）+ ON-2 示例项目入口×3（向导/Studio 空态/画布空态）——2026-07-17 核验补登（此前漏行） | #175 |
| PL-2 画布快捷键基建 + 第一批（删除/Esc/全选/缩放） | #176 |
| XM-1 视频元数据写侧（duration_ms/width/height 随缩略图同块落库） | #177 |
| docs/CLAUDE.md 维护（Commands 段 + 保护分支规则 + 结构快照同步） | #178 |
| 画布体验收口（首启适配/队列折叠/CineFlow 曲线/拖拽跟手/自定义配色/无限画布） | #179 |
| 画布卡片简约化 + 泳道钉死锚定 + 竖向泳道连线 | #180 |
| XM-1b 存量视频元数据启动回填（补齐 #177 写侧之前的历史视频） | #181 |
| DIR-1 数据目录迁平台惯例路径（存量 ~/InkFrame 一次性搬迁、失败回退、旧址标记；解锁 LB-10） | #183 |
| LB-10 每日 pg_dump 冷备（启动触发、-Fc 原子写、保留 7 份、失败不阻断；备份链 LB-08→07→10 收尾） | #185 |
| 全向无限画布（100k 居中定舞台、负坐标合法）+ 泳道终版语义（拖画布跟手、缩放不改道厚） | #186 |
| #186 对抗评审 P2-1 补：存量 >50k 越界节点加载期收敛进 ±kWorldReach（内存收敛不回写）+ 注释腐化 ×3 | #187 |
| LB-11 项目导出（zip=manifest+data+files 全保真含软删保 FK 闭包；.partial 原子写；项目卡菜单入口；清债#20） | #188 |
| LB-22 备份还原（scratch 库对换失败不动原库；三族备份分池+sidecar 校验；设置页数据区+启动失败面入口；顺带 start 单飞+JobQueue 关池 handle 必达） | #189 |
| LB-15 回收站 UI（≡GAP-2：sidebar 入口+项目回收站对话框、管理画布已删区；listTrashedByProject 三处补齐；债#11 以真入口收口；永久删除显式排除） | #190 |
| LB-18 诊断包（设置页打开日志目录+导出诊断 zip=info+logs/*+crashes/*+config 白名单两文件；红测钉死包内无 api_key，secrets.dev.json 结构性排除；W3 收官） | #191 |
| **LB-12 项目导入（W4 压轴/最大风险卡收官）**：全表 UUID 重映射+FK/JSONB 重写（含 type_config.character_ids）；zip 安全门（实测字节防 bomb/重名拒/保留名/UUID 段）；files 先行 staging+rename 收崩溃窗口；单事务+补偿零残留；roundtrip 大红测过；三大重操作互斥 | #192 |
| **Windows pg_ctl start 管道继承挂死（真机验收逮到的潜在 P0）**：postmaster 继承 Process.run 管道句柄致冷启动挂死至库进程落幕；Windows 分支改 inheritStdio；新增 realpg 门控真栈 E2E（真 initdb SCRAM→pg_ctl→迁移 v7→pg_dump→pg_restore 对换→teardown，5s 全链） | #194 |
| ON-2b 示例项目演示内容：createSample 单事务种子化（示例泳道+预填 prompt 的 image config 节点，纯本地零生成）；SampleSeed 经 ARB 由三入口传入 | #195 |
| ON-3 设置页 ffmpeg 状态行：仿安全存储探测模式；未找到=平台化指引（winget/brew+INKFRAME_FFMPEG），mac/win 外复用 exportVideoFfmpegMissing 防双源；重进设置页即重探 | #196 |
| ON-4 网络错误文案走查 + i18n pass：三轴并行审读（错误/一致性/僵尸）；45 键修订（错误归因与下一步动作、术语统一工作室/提示词/服务商/图片、省略号统一）；删 canvasNodeType* 6 僵尸键 | #197 |
| GAP-7 Inspector 测试欠账收口（预设点选应用+成本文案精确断言）+ ON-5 五屏空态 golden（Studio empty/error、Canvas empty、Gallery empty、Settings；ubuntu 铸线）——第 10 条（ON-3/4/GAP-7/ON-5）收官；**余 GAP-1 整卡、GAP-3 余量未清**（评审 P1 纠偏：勿宣「全部收官」） | #198 |
| GAP-3 余量收口（24 站点审计:方向读错并入横幅链;raw toString 上屏收敛——设置页探测诊断行为有意例外;base style 编辑器读错中止防空覆盖（评审 P2-3）;InkErrorBanner.onRetry 死参数删除;**InkAsyncSlot 判 YAGNI**——列表槽位 LB-06 已全收口） | #199 |
| **GAP-1 设置页 Custom Provider 编辑 UI（上线前必做最后一卡）**：CustomProviderStore 写侧（raw 保真+损坏拒写+原子写）;校验抽 core 纯函数双端共用;列表+表单+删除确认+重启生效常驻条;API Keys custom:* 行 displayName 顺带修——**随本卡合入,上线前必做 1-10 全部落地** | #200 |
| LEG-1 ④ 收口:双平台安装物根含 THIRD-PARTY.md(mac staging-ditto / win Copy-Item 进 Release,zip 侧流水线断言硬校验;DMG 随 staging 进卷)——beta 准入第 9 条全项 ✅ | #204 |
| QG-4 数据升级演练:CI populated-DB 迁移测(v1 起边迁边种+information_schema 全表非空守卫钉死「每个 schema PR 补种子」+真 PG 降级拒绝)+ realpg 升级演练 E2E(旧版 v6 数据目录→新版全链冷启数据存活)+ 发版 SOP 入 BUILD-RELEASE §15——beta.1 硬阻塞清剩 U1/U2 | #205 |
| **PKG-2A PG 二进制分发源（方案 A 上游直拉,beta 硬阻塞里唯一零用户依赖项收官）**：fetch-binaries.sh 双模式重写——upstream 默认（Win=EDB 官方 zip `upstream.lock` 锁 URL+SHA256+裁剪 bin/lib/share;mac=runner brew postgresql@17+make-relocatable,主版本匹配）,`PG_ARTIFACT_BASE_URL` 保留为方案 B 覆盖;`.partial` 原子落位+必需工具校验（含 pg_dump/pg_restore）;release.yml 去门控无条件 fetch;回归测试入 ci release-scripts;**顺带 QG-6 的 checksums.txt**（publish job 全资产 sha256）;本机真栈验收=EDB 裁剪产物过 realpg E2E 全链 | #201/#202 |
| **EX-3 导出进度+取消（Polish Wave 1 首卡,M4 E4）**：`ProcessStarter`/`RunningProcess` 流式进程通道（ISP 与 run() 分离,stderr 持续排干防背压;PR-2 备份/还原超时复用）→ concat 改 `-progress pipe:1` 流式解析 out_time_ms（微秒怪癖）,进度 0..1 单调、成功收口 1.0,分母=Σ所选 duration_ms 任一缺失→indeterminate;取消=token→kill→半成品清理→CancelledError.byUser 收敛 idle;**顺带债144 两件**:失败提示内嵌 banner+同名覆盖警示;波次设计+计划见 docs/superpowers/{specs,plans}/2026-08-05-* | #206 |
| **PR-2 备份/还原看门狗超时（Polish Wave 1;债153 收口）**：`runWithWatchdog`（EX-3 流式通道+定时 kill+硬截止 killGrace）;pg_dump 10min/pg_restore 30min,exit 0 优先于超时判定;还原 DROP tmp `WITH (FORCE)`+失败留证;**评审驱动加固**:Process.start 补关子进程 stdin（P1-1,pg 密码提示 10min 冻结→毫秒 EOF）、超时归因带 stderr、流异常留证不吞;进程 fake 迁 `test/_harness/fake_process.dart`（backup/restore/watchdog 共用+契约自测）;导出看门狗重估为不活动检测随 EX-2（债表该行更新） | #207 |
| **PR-3 画廊视频缩略图+播放（Polish Wave 1;M4 GA-1/2/7）**：`GalleryItem.thumbnailRelativePath`（读节点已落库 thumbnail_url,非现场抽帧,batch slot 无）→ tile 缩略图+播放/时长角标（缩略图缺失回退图标占位）→ 点击 existsSync 守卫开 canvas 共用 `video_lightbox`,视频缺失 → broken 态;GA-7=时长角标 mm:ss 回归断言;freezed 定向重生成（全量误删按 PLAYBOOK §2.2 checkout 恢复实证一次） | #208 |
| **PR-5 CH-1 视频角色注入（Polish Wave 1;M4 E5 首卡）**：`_injectCharacterRefs` 门改双分支——image 保持现规则;video 仅要求 maxRefImages>0（卡面禁令:不检查 modes,r2v/omni 不校验 mode 不炸）;注入后 mode 推断沿现逻辑 → imageToVideo;测试钉死「modes 只含 t2v 也注入」+ i2v 零注入 + image 回归 | #209 |
| **PR-4 画廊筛选/搜索 + 存为角色（Polish Wave 1;M4 GA-3/4）**：`GalleryFilter` 纯函数三轴过滤（kind/画布/canvasName 搜索,prompt 搜索 non-goal）+ 筛选条（分段/下拉/搜索框）+ no-match 态清除筛选;GA-4=image tile 菜单 → 命名对话框 → canvas charactersController.createFromImage（补偿在控制器,操作期 listenManual 保活防 autoDispose 竞态）;画廊根改 Material;ARB +7 键;评审 3×P1 全修（长画布名溢出/CharacterAssetError 逃逸/ref-after-dispose） | #210 |
| **PR-6 MOD-1 OpenAI 直升 gpt-image-2（Polish Wave 1;死线卡:gpt-image-1 2026-10-23 弃用）**：模型 ID 换新（1.5 亦 2026-12-01 退役不过渡）;契约兼容零结构改动（同步 b64/quality/无 response_format）;16:9/9:16 改**真比例**尺寸 1536x864/864x1536（gpt-image-1 时代只能凑 3:2,分镜第一刚需）;CostModel 对齐官方 medium 档 $0.041;PROVIDER-API §9.2/§13 同步 | #211 |
| **PR-7 LB-24 网络代理 P0（Polish Wave 1）**：`core/net/proxy_env.dart`——`proxyRuleFor` 纯函数（HTTPS_PROXY/HTTP_PROXY/ALL_PROXY/NO_PROXY 大小写双查,空串=显式禁用,凭据透传 `user:pass@`,loopback 恒直连,`*.glob`,解析不出目标才直连兜底——能解析但错误的值=连接错误同 curl）+ `applyEnvProxy` 挂 4 个 Dio 构造点（无代理变量时不动 adapter 保 dio 默认;注入 dio 零扰动）;接线层 e2e 双测（真 socket fake 代理/NO_PROXY 旁路）;SETUP.md 边界清单（SOCKS/端口段/CIDR 不支持,重启生效,TLS 拦截提示）;**P1 设置页代理区另卡** | #212 |
| **PR-8 框架债三小件（Polish Wave 1 收官）**：债150 建点视口中心（三入口,逆变换+散布,矩阵单测）;债145 restore 守卫扩三导航信号;债158 三大重操作互斥反向补查（导出查 import+restore,备份/还原区查 import+export）;债156 atomicZipWrite 裁定拆独立卡（M 级另窗） | #213 |
| **内置示例页（Codex 协作产出;DEMO-1 前哨）**：随包 AI 生成双图（1024² + 1536×864,`assets/showcase/`,无第三方版权不进 THIRD-PARTY）→ 只读展示页（不进 Gallery 聚合、不依赖 API Key）;入口三处（项目卡 ⋮ / **Studio 空态 CTA** / 命令面板 studio 上下文——零项目用户也够得到,评审 P1-1）;ARB 8 键 + 路由 `AppScreen.showcase`;评审修:出货文案去掉第三方工具名、InkCard 复用、ME-26 按宽解码、资产打包守卫测、路由+单栏分支补测。**演示内容规划见 `docs/superpowers/specs/2026-08-06-demo-content-brief.md`（3 模板 22 张 prompt + createSample v2 集成规格,待开卡）** | 本 PR |

## M1 补遗（审计发现的悬空项）

| 项 | 状态 | 备注 |
|---|---|---|
| 记住上次使用的 provider（新节点默认选中） | ✅ | 偏好 `lastImage/VideoProviderId`（按节点类型分记）；默认链=节点已存 > 上次使用（校验仍在能力列表）> first（#141） |
| 重启回上次打开的画布 | ✅ | 偏好记 `lastCanvasId/lastProjectId`；启动 `restoreLastSessionProvider` 校验画布/项目均未软删才恢复，主动回首页即清记录（#141） |
| 画布级重命名/删除 | ✅ | 项目卡菜单「管理画布」对话框，controller 走 canvasRepo update/softDelete（#141） |
| 设置页按钮统一设计系统组件 + onPrimary 暗色 bug | ✅ | onPrimary/onSecondary/onError → surfaceCanvas + InkButton 禁用态（#140）；api_keys 两个 Material 裸按钮换 InkButton（#141） |
| 项目复制 | 🅿️ | **全部机器已随 LB-12/#192 就绪**（重映射器/保真写侧/文件改名复制/补偿）：BP-11 只剩「导出到内存绕 zip + 一个菜单项」的组装活，按 backend 计划降为 M |

## 已延后 / 技术债

| 项 | 状态 | 原因 |
|---|---|---|
| T6 生成 N+1（findByIds） | 🅿️ | 接口加方法强制 15 个实现体同步改、收益边际；单独 PR |
| 三大上帝类拆分（JobQueue/GenController/CanvasView） | 🔵 | JobQueue 已拆（LB-03/#159：1168→504 行 + `job_queue/` 四协作者）；剩 GenController(BP-02)/CanvasView(BP-03) 上线后 |
| DI 层泄漏 ServerException + 迁移 DDL 编排在 provider body（AUDIT P1-5） | ✅ | LB-08/#153：`database_bootstrap.dart`（`core/di` 无 ServerException 泄漏） |
| buildUpdate 无列名白名单（AUDIT P1-11） | 🅿️ | 列名全部来自 core/db/columns.dart 常量，注入面受控；加白名单属加固 |
| components/primitives 双组件族无收敛文档（AUDIT P1-12） | 🅿️ | 需一篇 ADR 定分层规则 |
| InkWindowChrome 直依赖 window_manager（AUDIT P1-13） | 🅿️ | 单点依赖，抽象收益低；随 chrome 重构顺带 |
| 缩略图 300ms 固定延时 + open 无超时（AUDIT P1-16） | 🅿️ | media_kit 行为依赖，需真机回归验证 |
| _PromptPreview 双份拼装（AUDIT P1-17） | 🅿️ | 随 image_config_inspector 拆分处理 |
| JobRepository 胖接口拆分（AUDIT P1-18） | 🅿️ | 与 findByIds 同窗处理 |
| job_queue_panel 手写错误映射与 ink_error messageKey 双源（AUDIT P1-x2，缺 providerInvalidResponse 分支走 unknown 兜底） | ✅ | #164 退役 JobQueuePanel（-332 行），双源随组件删除即清 |
| ARCHIVE/footer 死 stub（AUDIT P1-x3） | ✅ | CV-1/#174 裁撤死件;LB-15/#190 以真回收站入口回归 footer（GAP-2 激活承诺兑现） |
| capabilities.pollTimeout 全仓零消费（AUDIT P1-x4） | ✅ | LB-02/#157：接入 JobQueue `_runJob`（pollTimeout/pollInterval 双读） |
| provider displayName 英文常量（AUDIT P1-7） | 🅿️ | 品牌名不译是有意为之；若要本地化需过 l10n 例外评审 |
| canvas_nodes_controller 乐观新增基于 previous 快照重建（丢更新竞态，VERIFICATION §5.3） | ✅ | LB-04/#158：`serial_mutation_queue.dart` FIFO 串行（nodes/edges/lanes/characters/presets 五处） |
| 未消费依赖卫生（riverpod_annotation/json_annotation/logging/uuid，VERIFICATION §5.4） | 🅿️ | 待 build_runner 卡点解除后一并清（codegen 链相关） |
| 嵌入式 PG `-A trust` 认证（AUDIT 安全附录） | ✅ | LB-07/#172：新集群 initdb 即 SCRAM-SHA-256 + 随机密码入 SecureStorage;存量 trust 集群零迁移继续可用（调研档见 [BLOCKERS-2026-07-06.md](BLOCKERS-2026-07-06.md) §3） |
| 补两档设计令牌（图标尺寸/控件高度） | 🅿️ | P2 一致性 |
| **build_runner 全量构建损坏**（analyzer 7.4.5 无法序列化 Dart 3.11 dot-shorthand,riverpod_generator 崩溃挂死;靠 asset graph 缓存掩盖,定向 `--build-filter` 可用） | 🅿️ | **调研已完成**（[BLOCKERS-2026-07-06.md](BLOCKERS-2026-07-06.md) §2）：唯一瓶颈 freezed 3.2.5 与 riverpod_generator 4.0.4 的 analyzer 约束相斥,freezed 3.2.6 stable 一出即与 Riverpod 3 迁移合并立项（同时解掉 custom_lint 卡点,见 §1）;盯 freezed#1353 |
| M2 Inspector 区 widget 级测试——参考图区/角色区/失败提示已补（PR #138）,预设点选应用与成本文案断言随 GAP-7 收口 | ✅ | #198：点选→字段+落库双断言;perCall 成本精确文案 |
| characters / prompt_presets 仓储真库 CRUD 集成测试 | 🅿️ | 仅作 UoW 装配件出现;对齐 postgres_repositories_integration_test |
| Inspector/网格 AsyncValue error 态吞没（镜像模式统一改 `.when`） | ✅ | LB-06/#166 主体 + #199 余量收口（24 站点审计:唯一真吞错=方向读错已修;library_sidebar 判良性降级加注释;InkAsyncSlot 判 YAGNI 不建）——**GAP-3 卡关闭** |
| 软删项目「可恢复」无 UI 入口（restore/listTrashed 仓储层已就绪） | ✅ | LB-15/#190：sidebar 回收站对话框（项目级）+ 管理画布已删区（画布级）;永久删除仍显式排除 |
| slot 状态字符串常量化（'generating' 等散落约 10+ 处,全仓既有约定） | ✅ | LB-01/#156：`core/constants/job_statuses.dart` 单一真相源 |
| canvas→generation 跨 feature import 违例（18 处 / 11 文件：job_state / jobs_registry / batch_results_controller / cost_estimator 等,违反 ARCHITECTURE §1.3 互 import 禁令） | 🅿️ | 待 import 边界 lint（custom_lint 卡点解除后）收口:上提共享模型到 core/ 或建白名单逐步清零 |
| 导出 busy 模态无取消/无超时（2026-07-08 深审:`Process.run` 无 timeout/kill 通道,busy 期 PopScope+禁按钮+barrier 三重封死,ffmpeg 挂起唯一逃生口=退出应用;export_video_dialog.dart:95 + system_process_runner.dart:11） | ✅ | **取消面**随 EX-3（本 PR）收口:ProcessStarter 流式通道（kill+stdout 行流）+ 对话框 determinate 进度与「取消导出」;取消=kill+清 .partial+CancelledError 收敛 idle;产物 .partial→rename,exit 0 优先于取消判定（已成功不误删）;流异常兜底 UnknownError 防 busy 永挂;退出期 onDispose 自动 kill 防孤儿。**超时看门狗未做**→拆下行新债 |
| 导出无超时看门狗（EX-3 评审 P2-7:仅交付取消;ffmpeg 卡死在不可达网络挂载等场景时进度停滞,取消按钮是唯一出口） | 🅿️ | PR-2 收了 pg 侧后重估:导出已有「取消导出」逃生口,且绝对超时会误杀将来 EX-2 的长转码——正解是**不活动检测**（progress 流 N 分钟无新行才 kill）,随 EX-2 转码窗同做 |
| 备份/还原超时在 UI 与普通失败不可区分（PR-2 复跑 P3-5,有意取舍保 ARB 零改动）:用户遇 30min 看门狗与秒级失败看到同一文案,盲目重试无提示 | 🅿️ | 低频;修法=RestoreOutcome/BackupOutcome 加 timedOut 位 + 专用文案键;随下一个动备份/还原 UI 的窗口顺带 |
| 导出同名覆盖的删后改名窄窗口（EX-3 复跑附带发现,PLAUSIBLE）:旧同名导出被播放器占用句柄时,`_deleteIfExists(outputFile)` 删不掉仅 warn→`renameSync` 失败→catch 清 .partial——整轮渲染只得一条泛化 export_io_failed（ffmpeg_video_export_service.dart:167-168） | 🅿️ | 低概率(需 Windows 真机文件锁实测);修法=rename 失败时保留 .partial 并出专门文案「目标被占用,产物在 <name>.mp4.partial」,或 rename 前 open 独占探测 |
| export 打磨两件（2026-07-08 深审）:失败 SnackBar 弹在模态 barrier 之下易漏看（export_video_dialog.dart:256）;同名输出 `-y` 静默覆盖无存在性提示（ffmpeg_video_export_service.dart:135） | ✅ | 随 EX-3（本 PR）:失败提示改对话框内嵌 InkErrorBanner;输出名同名时覆盖警示行（不阻断） |
| restore_last_session 抢占守卫过窄（2026-07-08 深审:只查 currentCanvasId,PG 就绪窗口内用户进 Settings/Gallery 会被恢复流程硬拉进画布;restore_last_session.dart:38） | ✅ | Polish Wave 1 PR-8（本 PR）:守卫扩为画布/画廊/Settings 三信号任一即放弃恢复;Settings/Gallery 两用例钉死 |
| link 智能默认 role 竞态残留（2026-07-08 深审:_defaultRole 读内存 edges 快照,首条 first_frame 边写在途时连第二条可产双 first_frame,uq_edges_live 不拦不同 source 同 role;link_action_controller.dart:83） | 🅿️ | 毫秒级低频;随上表「乐观新增竞态」并发模型债同窗处理 |
| 无单实例守卫：升级窗口旧实例并存时（macOS）目录 rename 仍成功,旧实例沿绝对路径重建旧址旁写媒体（DIR-1/#183 评审 P2;Windows 句柄锁天然拦截） | 🅿️ | 单实例锁/启动互斥另卡;既有 out-of-contract 场景被迁移放大,非 DIR-1 范围 |
| 深缩 + 厚泳道栈尾道内容不可达（#186 评审 P2-2:s=0.1×≥14 条默认泳道时位移项越出 100k 盒,皮可见内容点不中;根因=定舞台盒界 hitTest 短路 + Clip.none 越界绘制） | 🅿️ | 参数极端;与 P2-3 同根因族,随泳道命中层重构同窗处理 |
| 竖向末道 <200px 时标题栏按钮点不动（#186 评审 P2-3:皮 Positioned 盒宽=lanesTotal,溢出部分可见不可命中;标签区可拖是唯一逃生口） | 🅿️ | 同上根因族;修法=标题栏盒宽脱离道宽或按钮区折叠 |
| 建点位置固定世界 (200..600),全向漫游后建点必在屏幕外（#186 评审 P3-3:旧模型只右下漫游概率低,全向后被放大;命令面板/FAB/空态三入口同病） | ✅ | Polish Wave 1 PR-8（本 PR）:`pickViewportCenteredNodePosition`——视口中心经逆变换入世界坐标+±60 散布防叠点,三入口接线;视口未上报回退旧固定区（既有测试语义不变）;矩阵换算单测钉死 |
| 项目导出大文件路径（#188 评审 P2-4）:archive 包 deflate 把单文件压缩输出整段驻内存（GB 视频=GB 峰值）且同步压缩冻结 UI;附带 addFile 异常路径泄漏源文件句柄（Windows 进程退出才释放） | 🅿️ | 媒体改 store 不压缩 + Isolate.run 整体导出;与 LB-12 进度组件同窗做,v1 有 busy 防重入垫底 |
| OrphanFileReaper 转真删前必须 restore-aware（LB-22 评审 P3-1）:还原旧备份后新生成文件成 DB 孤儿——reaper 真删会吃掉「还原更新备份时还需要的文件」;当前 DRY-RUN 无害 | 🅿️ | LB-13b 真删灰度的前置不变量;修法=还原动作后重置 mtime 护栏或记还原水位 |
| pg_dump/pg_restore 无超时（LB-22 评审 P3-2）:挂死子进程让备份/还原 busy 永久锁 UI;与 EX-3 ffmpeg 同根因（ProcessRunner 无 kill/timeout 通道） | ✅ | Polish Wave 1 PR-2（本 PR）:`runWithWatchdog`（ProcessStarter 流式+定时 kill+**硬截止** timeout+killGrace——kill 无效也不永挂）;备份 10min/还原 30min,超时=kill+带 stderr/exit_code 归因 warn;exit 0 优先于超时判定（已成功不误删,同 EX-3 不变量）;还原 DROP tmp 加 `WITH (FORCE)`（超时 kill 后 backend 可能仍占库）+失败留证;**顺带评审 P1-1**:Process.start 补关子进程 stdin（对齐 Process.run,pg 密码提示从 10min 冻结回毫秒级 EOF 失败,EX-3 ffmpeg 同受益）;进程 fake 迁 _harness（backup/restore/watchdog 共用+契约自测;ffmpeg fake 因进度流语义专用留原地） |
| 还原对换的 retired 库残留（DROP 失败仅 warn）与 swap_stranded 极端夹缝无启动期清扫/救援 | 🅿️ | 空间代价可接受;随 LB-12 同窗盘点:启动 housekeeping 扫 inkframe_retired_*/inkframe_restore_tmp 报告或回收 |
| 回收站恢复绕过名字唯一性（#190 评审 P3-2）:建 Alpha→删→再建 Alpha→恢复旧 Alpha=工作库两个 Alpha;schema 无唯一约束,create/rename 的 UI 校验管不到 restore | 🅿️ | 不炸纯 UX 漂移;修法=restore 前查同名给改名/后缀,或列表 UI 容忍同名靠时间区分 |
| zip `.partial` 落盘骨架三份逐字复制（LB-10/11/18；#191 评审 P3-3 复发实证:自吞守卫没跟着骨架走） | 🅿️ | 抽 `atomicZipWrite(target, build)` 共享件并内置 #188 P2-5 自吞排除;**PR-8 范围裁定拆独立卡**(M 级:三服务 fake 契约面,与本簇 S 件不同窗;修法不变) |
| pg.log 无轮转（pg_ctl -l 追加写;logger 的 10MB 预算只认 inkframe.* 前缀）——诊断包/磁盘体积长期无界（#191 评审 P3-5） | 🅿️ | pg.log 轮转（启动期截断/按大小滚动）或诊断包按 mtime 截取最近 N 份 |
| 三大重操作互斥只在导入侧单向查（LB-12 拍板 9）:还原/导出入口不查 projectImportBusyProvider——导入进行中仍可点还原 | ✅ | Polish Wave 1 PR-8（本 PR）:反向补查——项目导出入口查 import+restore busy,备份/还原区查 import+export busy;import 侧原有三方检查不变 |
| 导入补偿删除失败→projects/{uuid} 孤儿目录无回收路径（#192 评审 P3-2:无 .import- 前缀 sweep 不认,reaper 又 DRY-RUN）;另记拍板 4 三处字面偏差（U+FFFD 奇名可过/最终路径长未预检/isWithin 代 resolveInProject）均安全失败 | 🅿️ | 随 LB-13 reaper 转真删同窗:无行背书目录纳入回收;字面偏差随安全面复审顺修 |
| **迁移纪律备忘（#192 评审 P3-6）**:导入的列白名单过滤依赖「迁移只加可空/有默认列」——将来任何「新增 NOT NULL 无默认」迁移会让旧项目包导入必炸 | 🅿️ | ADR-0012 补一句:新增列必须可空或带默认,否则同时给导入侧加填充逻辑 |
| GAP-1 评审 P3 残留（#200）:①unknownTemplate 在 UI 错误文案映射到 InvalidId 键（当前不可达——模板恒下拉;改自由输入即活雷,补专用键或注释）;②_openEditor 读失败报「保存失败」文案微错位;③写无顺序化（模态门控下重合概率趋零,硬化=_queue.then 串行链）;④_parseEntry seenIds 在 template/url 校验前占坑,被拒条目致后续同 id 合法条目误判 duplicate（既有债非本卡引入）;⑤section 内 provider 定义应迁 features/settings/providers/（风格） | 🅿️ | 均低害;①随模板扩展窗强制处理 |
| GAP-3 评审 P3 残留（#199）:①方向读错期 lane_toolbar 置灰未做（二元域无损毁,但 toggle 到不了 horizontal 的怪异 UX）;②横幅三源 `??` 链+单 `_dismissed` 遮蔽——关掉 edges 错后并发 lanes/direction 错不上屏（改集合）;③非 InkError→errorUnknown 后无任何日志线索（此前 raw toString 至少可报障）,建议 error 分支补 log 或 ProviderObserver.providerDidFail | 🅿️ | ①②低害 UX;③可观测性,随日志面收口 |
| ON-5 评审 P3 残留（#198）:①golden sentinel 单点——删 studio_empty.png 五测静默 skip 而 node_card 仍 ran>0 骗过整 job 守卫;评审提的 `skipped>0&&baselines>0→fail` 会误伤增量铸线 bootstrap（本 PR 自身流程即反例）,需更细粒度方案;②成本断言 0.01×1 测不出漏乘 batch,补 maxBatchSize>1→\$0.02 用例;③ci.yml 与 update-goldens.yml 双 pin FLUTTER_VERSION 升级必须同步+重铸 | 🅿️ | ①设计再议 ②一测的事 ③升级 checklist 项 |
| ON-3 评审 P3 残留（#196）:卸载 ffmpeg 后设置页旧 Available 滞留（hit 缓存 app 级,设置页不调 invalidate;导出失败路径会自愈）;PATH 命中显示裸 `ffmpeg` 当路径 | 🅿️ | 低害:重启/导出失败自愈;若做刷新按钮同窗顺修 |
| PKG-2A 评审 P3 残留:fetch-binaries macOS upstream 无架构核对——arm64 机上 INKFRAME_PG_PLATFORM=macos-x64 会把 arm64 二进制落进 x64 目录且本机 verify 照过（操作员失误场景;release.yml 现只建 arm64;make-relocatable 旧脚本同病） | 🅿️ | 随 macos-13 x64 matrix（PKG-7 真做）同窗加 uname 对 PLATFORM 的核对 |
| ON-2b 评审 P3 三条（#195）:①真 PG 回滚测只走 projects+canvas 两仓储,建议扩成与 createSample 同构四步;②泳道带厚 400 魔数散落三处（接口默认/注释/测试）,建议提 kDefaultLaneSize;③示例 laneStylePrompt 走 zh 本地化与 base_style_presets「模型合约保英文」惯例有张力（用户可见可编辑,判定可接受）——产品可拍板改为仅本地化 label | 🅿️ | ①②低成本顺窗;③产品取舍,英文语系 provider 出图质量考量 |
