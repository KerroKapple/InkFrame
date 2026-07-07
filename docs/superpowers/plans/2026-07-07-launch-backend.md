# 上线规划:后端/数据安全任务卡(2026-07-07)

> 本文冻结于 2026-07-07(main@b2be25e)。开卡前先按当前 main 复核 file:line;完成状态记 BOARD/MASTERPLAN,不回写本文。
> MASTERPLAN §3 的明细。基于 main@b2be25e 第一手核验(全部 file:line 已核)。
> 开工前先读 `docs/EXECUTION-PLAYBOOK.md`。
> ⚠️ **与 UI 规划的去重**:LB-06 ≡ UI 卡 GAP-3(AsyncValue error 态)、LB-15 ≡ GAP-2(回收站 UI)、
> LB-05 与 GAP-8(渲染队列)关联——同一工作只排一张,以先开工者为准,另一张标记合并。

## 0. 现状核实要点(供任务卡直接引用)

- **JobQueue 1168 行**:调度(L85-263)/单任务生命周期+poll(L267-505)/持久化 helpers(L507-673)/
  **产物落盘 ~450 行**(L629-1083,inline/remote×单/批 4 分支)/_Handle(L1116-1168)。
- **PG trust**:initdb `-A trust`(pg_controller:71-77);Endpoint 无 password(di/database:56-64);
  `pgMigratedPoolProvider` 在 DI body catch ServerException+编排迁移=债 P1-5 实体。
- **乐观竞态**:五处(nodes/edges/lanes 控制器 + characters/presets)均"入口快照→await→快照重建"
  (docs/PROGRESS-VERIFICATION-2026-06-29.md §5.3 判 P1 真丢数据)。
- **错误映射双源**:job_queue_panel `_errorMessage` 手写 switch 缺 providerInvalidResponse→错落
  errorUnknown;`l10n_x.dart:12-31` 的 l10nError 已完整。
- **jobs purge 蒸发画廊数据+孤儿文件**:purge 硬删 jobs→CASCADE 清 batch_results 行(job_id NOT NULL)
  →非主图批量产物失去 DB 引用;**全仓产物文件零删除点**(grep 穷尽)。
- **崩溃一致性**:启动三件套齐(bulkTransition+finalizeAllPending+purge)、stale pid 清理、有序退出;
  **缺口=空 result 节点无人收敛**(nodes 失败清理仅 _track 内存路径)。
- **备份/导出/导入:零存在**;AppPaths=~/InkFrame/{logs,config,database,projects}。
- **可观测性**:logger 轮转/脱敏齐;**lib 无 runZonedGuarded/FlutterError.onError/
  PlatformDispatcher.onError**——未捕获异常凭空消失;`inkframe.crash.*` 只有轮转豁免,写入器不存在;
  无日志目录/诊断包入口。
- **性能**:400 节点 build 亚线性有护栏;gallery/canvas 读=单查询;JobQueue cancel O(1) 有 N=10000
  基准;生成路径 findById×7 非热点。真 GPU 帧率未测(BP-13)。
- **发布线**:release.yml 守卫式全链路已在;**ci/release 均不跑 build_runner/gen-l10n(生成物入库)
  → build_runner 损坏不在发布关键路径**;PgBinaryLocation 无 pg_dump getter。
- project 的 listTrashed/restore 就绪;**canvas 仅 restore 就绪,无 listTrashed**——LB-15 需新增
  `CanvasRepository.listTrashedByProject`(接口+PG 实现+fake 三处,仿 project 版)。

## 1. 债表处置(24 行 = BOARD 23 + 项目复制)

**上线前必修**:#2 JobQueue 拆分(LB-01→03)、#3 DI 泄漏(LB-08)、#10 错误映射(LB-05)、
#11 死 stub 最小处置(随 LB-15 隐藏)、#12 pollTimeout(LB-02)、#14 乐观竞态(LB-04)、
#16 PG SCRAM(LB-07)、#20 两仓储集成测(借道 LB-11/12)、#21 AsyncValue(LB-06)、
#22 回收站(LB-15)、#23 slot 常量化(LB-01)。
**条件必修(外部触发)**:#18 build_runner——freezed 3.2.6 stable 发版即执行 LB-21;不阻塞发布。
**上线后**:#1 findByIds+#9 JobRepository ISP(同一接口变更窗口 BP-01)、#5 组件族 ADR、
#7 缩略图延时、#8 _PromptPreview、#15 依赖卫生(并入 LB-21)、#17 令牌两档、#19 Inspector 测试、
#24 项目复制(BP-11,复用 LB-12 机器后降为 M)。
**永久接受**:#4 buildUpdate 白名单(列名全来自常量,无新威胁模型)、#6 InkWindowChrome 直依赖、
#13 provider displayName 英文(有意决策)。

## 2. 任务卡通用惯例块(执行者必读)

TDD 先红后绿;禁 catch Exception/dynamic 只捕具体 InkError(渲染路径豁免 PathSecurityError);
用户可见文案 en/zh ARB 同 commit + gen-l10n(**奇偶闸=test/l10n/arb_hygiene_test.dart,随全量测试跑**);
样式全 token;codegen 只用 `--build-filter` 定向;测试替身=手写 Fake 进 test/_harness(禁 mock 框架、
禁 UnimplementedError);真库集成测走 pg_test_harness(TEST_PG_URL 门控);golden 以 CI 为准
(本地 3 假阳白名单);UPDATE 必带 updated_at(quality gate 扫描,白名单表 edges/jobs/batch_results/
schema_version);flutter 用绝对路径;覆盖率用 scripts/coverage/report.sh;动 schema/行为的 PR 同
commit 更新 DATABASE/ARCHITECTURE 对应节。

## 3. launchBlockers(LB-01~24)

### A. 架构与正确性

- **LB-01 slot/job 状态字符串常量化**(S):新 `core/constants/job_statuses.dart`(jobs 7 态+slot 4 态,
  对齐 DATABASE CHECK);grep 穷尽约 **~30 行、5 个文件**(含 purge SQL 内嵌状态字面量)纯机械替换。
  验收:grep 仅命中常量文件;全测绿。是 LB-03 的降噪前置。
- **LB-02 capabilities.pollTimeout/pollInterval 接入**(S):`_runJob` 取
  `caps.pollTimeout ?? _pollTimeout` 传 `_pollLoop`;红测=fake provider 声明短超时断言生效;
  N=10000 cancel 基准仍绿。
- **LB-03 JobQueue 拆分(1168→编排器 <500 行)**(L,依赖 LB-01/02):
  拆出 ①`job_queue/job_media_persister.dart`+接口(四条落盘分支+slot patch,L629-1083;
  「依赖未注入=跳过」语义改「注入 null persister」);②`job_queue/job_state_persister.dart`
  (持久化 helpers L507-673+init 启动恢复,**签名与 affectedRows 语义一字不改**);
  ③`job_queue/job_handle_impl.dart`(_Handle,last-value 重放契约)。
  **L629-673 重叠区裁决**:slot patch 三件套(_updateSlot/_slotSuccessPatch/_slotErrorPatch)随
  media persister;_persistCancel 留 state persister;_truncate 两处共享(放公共 util)。
  **竞态裁决 _lostToCancel/_arbitrate 必须留在编排器**。迁移步骤:先跑 test/services 建绿基线
  (特征化测试网)→逐块搬→每步全量跑。验收:<500 行;含 cancel 基准/迟到重放/批量部分成功全绿;
  ARCHITECTURE §5.1 引用与 CLAUDE.md 快照同步。风险:若 _persistRemoteUrlsBatch 覆盖不足先补测再搬。
- **LB-04 乐观更新丢更新竞态(五处)**(M):红测=Completer 门控 fake repo 让两个 addNode 交错,
  断言终态两节点都在(现实现丢一个);修法=每控制器加 FIFO 串行队列
  `_tail = _tail.then(...)`,mutation 整体包进 `_serialized`(串行化后快照-回滚自动安全);
  保留 _alive 守卫;nodes/edges/lanes 同模式。**同型竞态还在 `characters_controller.dart`
  (rename/delete)与 `prompt_presets_controller.dart`(rename/delete)——纳入修复范围,
  或在卡内注明接受理由**。风险:确认控制器方法间无相互调用(现状无)防死锁。
- **LB-05 job_queue_panel 错误映射统一 l10nError**(S):删手写 switch 改调 l10nError;
  红测=JobFailed(providerInvalidResponse) 断言正确文案。⚠️ 与 UI 卡 GAP-8 联动:若 GAP-8 决定
  删除未挂载的 JobQueuePanel,本卡自动消解——先拍 GAP-8。
- **LB-06 AsyncValue error 态(≡ UI GAP-3,单排一张)**(M,依赖 LB-05——若 GAP-8 裁决删除
  JobQueuePanel,LB-05 消解,本卡依赖自动脱落,ink_async_slot 不需要 LB-05):A 组必改站点
  =batch_results_grid:25 / image_result_inspector:23 / image_config_inspector:504,651-654,676,949-968 /
  node_inputs_section:45-46 / canvas_view:390-394(边/泳道失败→非阻断 banner,节点照渲染);
  **勿动的合法兜底**=canvas_screen:26 / inspector_status_panel:81 / lane_toolbar:22 / api_keys_section:135。
  每站点一条 AsyncError override 测试。

### B. 数据安全与完整性(上线硬门槛)

- **LB-07 PG trust→SCRAM-SHA-256**(M,依赖 LB-08;**D-4/U7**——存量库处置口径以拍板为准,
  本卡默认按 Zero-BC 仅新 initdb 生效书写):PgProcessRunner.initdb 加 pwFile 参数,
  `--auth=scram-sha-256 --pwfile=...` 替换 `-A trust`;PgController 注入 SecureStorage:
  生成 32 字节随机密码→临时 pwfile→initdb→finally 删→密码入 Keychain;Endpoint 加 password
  (SslMode.disable 保留,回环内)。存量库 Zero-BC:仅新 initdb 生效(trust 集群带密码连接照常成功,
  无迁移);**取密码路径必须容忍 Keychain 无该条目(存量 trust 集群),缺失时传 null/跳过**。
  红测=fake runner 捕获 initdb 参数+pwfile 生命周期。验收含手工:pg_hba 含 scram、
  裸 psql 被拒、App 正常。风险:用户清 Keychain→LB-09 必须给「重置数据库」指引;
  pool provider 变 async 取密码,勿破 AppTeardown 在途 await;
  **签名身份变更×Keychain ACL**:alpha 未签名 app 写入的条目在 Developer ID 签名版可能不可读——
  PG 密码拿不到=库打不开;QG-4 升级演练必须含 unsigned→signed 真机路径(与 release 计划 QG-4 联动)。
- **LB-08 DatabaseBootstrap 收口 DI 泄漏**(S):新 `storage/database_bootstrap.dart`
  (pgcrypto 幂等+migrate,ServerException 在此边界翻译);provider body 缩为一行;
  验收:`grep ServerException lib/core/di/` 归零;幂等两次 run 集成测。
- **LB-09 启动失败 surface**(M,依赖 LB-08,与 LB-07 联动):app 级门 watch pgMigratedPoolProvider,
  失败→全屏错误视图(标题/正文含日志路径/「重试」=invalidate 链/「打开日志目录」);
  SCRAM 后 28P01 分支给重置指引;PgLifecycleError(StateError 系)在 DI 边界翻 LocalIOError。
  红测=override AsyncError 断言视图。风险:重试 invalidate 链需真机验证(PgController 有内部状态)。
- **LB-10 自动 pg_dump 冷备(每日,保留 7 份)**(M,依赖 LB-07/08):PgBinaryLocation 加 pgDump
  getter(fetch-binaries 载荷确认含 pg_dump/pg_restore——LB-20 联动);**AppPaths 需新增 backups
  getter + ensureInitialized 项**;新 DatabaseBackupService:
  `-Fc` dump 到 AppPaths.backups,当日已有跳过,按日期序保留 7 份,PGPASSWORD 经 env(取 Keychain);
  任何失败仅 warn 绝不阻断;pool 就绪后 post-frame 触发不挡首帧;恢复手册进 SETUP.md。
  开发机无打包 PG→跳过+warn 不算失败。
- **LB-11 项目导出(整项目 zip 带产物)**(L):新 ProjectArchiveService;zip=manifest.json
  {formatVersion,schemaVersion,appVersion,exportedAt} + data.json(project+canvases+nodes+edges+
  lanes+characters+presets+**拥有 success slot 的 jobs 行+其 batch_results 行**——slot 必须连 job
  一起带,job_id NOT NULL)+ files/=projects/{id} 全量;流式写;pubspec 加 archive(纯 Dart);
  入口=项目卡菜单+getSaveLocation。红测用 plain test()(testWidgets 禁真 IO——TD-003);
  **借道补 characters/prompt_presets 真库 CRUD 集成测(债 #20)**。zip 内路径统一 `/`。
- **LB-12 项目导入(ID 重映射+JSONB/FK 重写)**(XL,依赖 LB-11、**D-4(拍板结果决定 manifest
  版本策略)、D-BE-2**,**全计划最大风险卡,放最后**):
  manifest 版本不匹配显式拒绝(Zero-BC);全表旧→新 UUID 映射;重写 canvases.project_id、
  nodes.canvas_id/source_node_id(自引用两趟:先 NULL 后 patch)/lane_id、edges 双端+
  **edges.canvas_id**、**style_lanes.canvas_id**(FK→canvases)、
  jobs 三 id、batch_results 三 id、characters/presets.project_id、projects.cover_node_id;
  type_config 内路径 canvas 相对无需重写,但 files/ 树的 canvases/{旧id} 段按映射改名;
  **zip slip 防护:解包前逐条目校验(拒绝绝对路径/含 `..` 段/盘符前缀/符号链接,canonical prefix
  检查落在目标目录内)+ 条目大小/总量上限**;
  行写入单 UoW 事务(FK 顺序);文件复制在提交后,失败补偿删目录;
  **红测先行:pg harness 全链路 roundtrip**(行数相等/gallery 相等/产物可解析/损坏 zip 零残留)
  + **恶意 zip 红测**(路径穿越/超限条目被拒且零残留)。
  产出「项目复制」(BP-11)的全部机器。
- **LB-13 jobs purge 语义修正+磁盘孤儿回收**(L=A(S)+B(M),依赖 LB-01,建议 LB-03 后):
  切片 A:purge SQL(复数——**`purgeExpired` 与 `purgePerCanvasCap` 两个方法都要加**)加
  `AND NOT EXISTS(... br.status='success')` 守卫——有 success slot 的 job 永不 purge
  (保画廊,→ 决策 D-BE-1);切片 B:OrphanFileReaper 枚举 projects/*/canvases/*/{images,videos},
  引用集=全部 nodes(**含软删**——可恢复性)的三个 url 键 ∪ batch_results.output_url(接口加
  listAllOutputUrls);**nodes 侧全量扫描无现成方法——需对等新增只读接口(如
  NodeRepository.listAllMediaUrls 或按画布循环 listByCanvas,执行者按 T6 债权衡)**;
  删「未引用且 mtime>7 天」;启动 post-frame+时间戳节流(≥7 天一次);
  **误删是最高危——mtime 护栏+软删引用保留+只删两类子目录三重保险,首版可 dry-run 灰度一版**。
- **LB-14 崩溃遗留空 result 节点收敛**(M,依赖 LB-03):NodeRepository 加
  softDeleteEmptyOrphanResults(),SQL 全文:

  ```sql
  UPDATE nodes SET deleted_at = now(), updated_at = now()
  WHERE node_role = 'result'
    AND deleted_at IS NULL
    AND COALESCE(type_config->>'image_url','') = ''
    AND COALESCE(type_config->>'video_url','') = ''
    AND COALESCE(type_config->>'thumbnail_url','') = ''
    AND NOT EXISTS (SELECT 1 FROM batch_results br
                    WHERE br.node_id = nodes.id AND br.status = 'success')
    AND NOT EXISTS (SELECT 1 FROM jobs j
                    WHERE j.result_node_id = nodes.id
                      AND j.status IN ('pending','submitted','polling'))
  ```

  (**SET deleted_at+updated_at**——quality gate 扫 updated_at;success-slot 护栏的存在理由:
  批量部分成功后崩溃时主图尚未写入节点,仅凭三个 url 键判空会误收敛仍有 slot 产物的节点);
  init() 孤儿回收后调用,失败仅 warn;
  全部 NodeRepository 实现体同步(共享 fake 真逻辑,ad-hoc fake 诚实返回 0);
  语义=空壳自动进回收站(软删可经 LB-15 恢复)。
- **LB-15 回收站 UI(≡ UI GAP-2,单排一张)**(M):**前置=先补 `CanvasRepository.listTrashedByProject`
  (接口+PG 实现+fake 三处,仿 project 版——canvas 侧现只有 restore 无 listTrashed)**;
  Studio 入口+trash 列表(项目名+删除时间+
  Restore);画布恢复挂「管理画布」对话框加已删区;**顺带隐藏 ARCHIVE/footer 死 stub(债 #11
  最小处置)**;首版不做永久删除(涉磁盘清理策略,显式排除)。
- **LB-22 备份还原路径(app 内)**(M,依赖 LB-09/LB-10):
  为什么=SCRAM 后密码在 Keychain,用户无法手工 pg_restore——「备份天天做,用户永远还原不了」;
  怎么做=启动失败视图(LB-09)加「从备份还原」入口 + 设置页数据区(备份列表/立即备份/还原确认),
  app 内部持有密码调 pg_restore(先 dropdb/createdb 或 `--clean`),**还原前自动再备份一次**;
  验收=损坏库→从最近备份一键还原→数据可见;
  风险=还原中断的半状态(先备份再还原兜底)。

### C. 性能(现状达标,只补守卫)

- **LB-16 启动计时埋点+预算验收线**(S,依赖 LB-08):Stopwatch 包各 bootstrap 段+首帧+PG ready,
  logger.info('app.lifecycle', extra:{stage,ms});验收线进 perf-baseline.md:温启首帧 <2s、
  PG ready(温)<5s、冷启含 initdb <15s;双平台实测数值填入。
- **LB-23 内存基线**(S-M):perf-baseline.md 加内存水位节(空载/画廊 100 项/连续生成 20 张后的
  RSS,双平台实测);ImageCache 上限策略评估;画廊 tile `Image.file(cacheWidth:)` 缩略解码
  列为 GA-1/GAP-5 验收项;keepAlive provider 持大对象盘点(17 处)记 BP 系。

### D. 可观测性

- **LB-17 全局错误钩子+crash 落盘**(M):runZonedGuarded 包 runApp + FlutterError.onError +
  PlatformDispatcher.onError → logger.error + CrashReporter(写 inkframe.crash.{ts}.log,
  超 3 份删最旧——轮转豁免逻辑已在等它)+ flush;崩溃文件无 extra(天然无敏感);
  onError 回调内再崩→顶层兜底 try 是体系显式豁免点(注释说明)。
- **LB-18 日志目录入口+诊断包**(M,依赖 LB-17):设置页两按钮(打开日志目录=FolderOpener 小抽象;
  导出诊断 zip=logs/*+pg.log+preferences.json+custom_providers.json+版本);
  **红测断言包内无 api_key 字段**(key 全在 Keychain,custom_providers.json 按设计无 key);
  archive 依赖与 LB-11 共享。

### E. 发布线与工具链

- **LB-19 CI 的 ARB 奇偶保护核实**(XS→S):⚠️ 原卡引 ARCHITECTURE §8.4「CI 无 ARB 校验」——
  **该陈述疑似过时**:`test/l10n/arb_hygiene_test.dart` 随 CI 全量测试跑,奇偶已是硬闸。
  执行者先核实(故意删一个 zh key 开 PR 看 CI 是否红);若已覆盖,本卡改为修正 ARCHITECTURE §8.4
  陈述;若未覆盖(如该测试被 tag 排除),再加 CI job。
- **LB-20 Release 流水线收口(资源置备)**(M-L,纯并行,第 0 天启动):
  与发布工程规划的 PKG-1/2/3 同一工作(以那边任务卡为准);本卡补充两点:
  ①PG 工件载荷确认含 pg_dump/pg_restore(LB-10 依赖);②干净 VM 双平台「装→首启 initdb→建项目→
  配 key→真生成一图→重启数据在」是最终 gate。
- **LB-21 build_runner 工具链解封(条件任务:freezed 3.2.6 stable 触发)**(M):
  单 PR:riverpod 3.3.x+riverpod_generator 4.0.4+freezed 3.2.6+json_serializable ^6.14+
  build_runner ^2.15;删 custom_lint/riverpod_lint 2.x 改 analysis_options 顶层 plugins
  (**防零规则假绿:先故意写一处违规确认真报错**);ci 删 custom_lint step(analyze 原生带插件
  诊断成硬闸);顺带清依赖卫生(债 #15);验收唯一硬证据=删 .dart_tool/build 后全量 build_runner 跑通。
  风险:riverpod 3 autoDispose 语义差异——全测试网+手工回归画布/生成主链。

### F. 网络环境

- **LB-24 网络代理支持**(M,上线前):
  为什么=dio/dart:io 默认不读系统代理,中国用户连不上 OpenAI/Gemini,与中文市场定位直接冲突;
  怎么做=P0 支持 `HTTPS_PROXY`/`HTTP_PROXY` env(dio HttpClient findProxy)+ 文档;
  P1 设置页网络区(跟随系统/手动 host:port/不代理),双平台系统代理读取;
  验收=设代理后 fake 端点经代理可达(单测 findProxy 逻辑)+ 手工真代理冒烟;
  风险=证书/TLS 拦截场景报错文案。

## 4. postLaunch(BP-01~16,略)

BP-01 仓储接口变更窗口(findByIds+JobRepository ISP/死方法删);BP-02 GenerationController 拆分
(RefImageResolver/TaskFactory/SubmissionTransaction/JobTracker);BP-03 CanvasView 拆分+视口裁剪
(触发=BP-13 帧率证据);BP-04 组件族 ADR;BP-05 缩略图延时;BP-06 _PromptPreview;BP-07 ARCHIVE
功能定义;BP-08 令牌两档;BP-09 Inspector 测试;BP-10 两仓储集成测独立版;BP-11 项目复制
(复用 LB-12 机器降 M);BP-12 JobQueue 自动重试(退避,LB-03 后);BP-13 真 GPU 帧率
integration_test;BP-14 gallery 时长/缩略图(与功能规划 GA/XM 卡合并);BP-15 性能档位联动;
BP-16 Key 验证缓存 TTL 等 Planned 小项。

## 5. 波次与依赖图

- **W0(即刻,S 簇全并行)**:LB-01、LB-02、LB-05(与 W0 有时序张力:先拍 GAP-8 处置,
  若删 panel 本卡消解)、LB-08、LB-19;同时启动两条外部长线:
  LB-20(资源置备,日历时间真关键路径)、LB-21(盯 freezed 发版,窗口开即插队)。
- **W1(正确性簇)**:LB-03、LB-04、LB-06、LB-17。
- **W2(数据安全地基)**:LB-07、LB-09、LB-13、LB-14、LB-16。
- **W3(主菜)**:LB-10、LB-11、LB-15、LB-18、LB-22(接 LB-09/10 尾)。
- **W4(压轴)**:LB-12(最大风险卡,不阻塞其余)。

```
LB-01 ─┬→ LB-03 ─┬→ LB-13B    LB-08 ─┬→ LB-07 → LB-10 → LB-22(LB-09 联动)
LB-02 ─┘         └→ LB-14            ├→ LB-09(联动 LB-07 密码分支)
LB-05 → LB-06                        └→ LB-16
LB-11 → LB-12 → BP-11    LB-17 → LB-18    LB-04(W1)/LB-15(W3)/LB-19(任意)/LB-23、LB-24(任意,上线前)
```

体量:S×5 + M×10 + L×3 + XL×1 ≈ 22-28 人日(不含 LB-20 等待时延与 LB-21 外部窗口);
复审新增 LB-22(M)/LB-23(S-M)/LB-24(M)另计 +3-5 人日。

## 6. 决策点(→ MASTERPLAN §9)

- **D-BE-1 purge retention 语义**:A(推荐). 有 success slot 的 job 永不 purge(保画廊)/
  B. purge 时连文件一起删(接受 30 天窗口)。
- **D-BE-2 导入是否携带 jobs**:A(推荐). 仅携带拥有 success slot 的终态 jobs 行(slot 的 FK 需要)/
  B. 全舍弃(画廊在导入项目不可见)。
