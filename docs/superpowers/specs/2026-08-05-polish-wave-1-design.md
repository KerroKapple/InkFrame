# Polish Wave 1 —— 功能与框架打磨波次设计（2026-08-05）

> **背景**：签名线（U1/U2）用户已明确挂起（「先不管证书」）；本波次执行「打磨各种功能和框架」。
> **选卡铁律**：只做**无需产品拍板**的卡——被 D-M4 系决策阻塞的 SB-1、GA-5/6、AG-4/5、EX-2
> 全部避开，留给用户异步拍板（PLAYBOOK §6）。范围 = 存量功能补全 + 框架债清偿 + 模型死线。
> **状态记账**：完成状态只记 BOARD/MASTERPLAN；本文是波次开工快照，不回写。

## 波次总览（8 个 PR，按序执行）

| # | 卡 | 规模 | 一句话 |
|---|---|---|---|
| PR-1 | EX-3 + 债144 | M/L | 导出进度+取消；ProcessRunner 流式通道（框架根） |
| PR-2 | 债153 | S/M | 备份/还原 pg_dump/pg_restore 接超时+kill |
| PR-3 | GA-1/2/7 | S | 画廊视频缩略图+点击播放+时长确认 |
| PR-4 | GA-3/4 | M | 画廊筛选/搜索 + 图片存为角色 |
| PR-5 | CH-1 | S/M | 视频生成自动带角色图 |
| PR-6 | MOD-1 | S | OpenAI gpt-image 升级（2026-10-23 弃用死线） |
| PR-7 | LB-24 P0 | S/M | HTTPS_PROXY 环境变量代理支持 |
| PR-8 | 债156/158/150/145 | M | atomicZipWrite 共享件、busy 归一、建点视口中心、restore 守卫 |

**排序理由**：PR-1/2 是共病根框架件（ProcessRunner 无 kill/timeout 是导出/备份/还原三处
挂死风险的同一根因），先落框架再做上层打磨；PR-3~5 用户可见功能补全；PR-6 有硬死线但
2.5 个月窗口足够排第六；PR-7/8 独立小件收尾。

**明确不做（等拍板/依赖）**：EX-1′ narrative 自动排序（依赖 SB-5 未落地）；EX-2 转码归一
（D-M4-6）；GA-5 发送画布（D-M4-2）/GA-6 删除（D-M4-3）；SB 线全部（D-M4-1）；
CH-2 角色区抽取（含非机械决策，下波）；MOD-3 Gemini 升级（随 PR-6 研究结论另评）。

## PR-1：EX-3 导出进度+取消 + ProcessRunner 流式通道

**为什么**：导出 busy 模态无取消/无超时，ffmpeg 挂起唯一逃生口=杀应用（BOARD 债143）；
失败 SnackBar 弹在模态 barrier 之下易漏看、同名输出 `-y` 静默覆盖（债144）。

**做法**（卡面 EX-3 + 现场核实）：
1. `core/interfaces/process_runner.dart` 加流式通道（保留现 `run()`）：
   ```dart
   abstract class RunningProcess {
     Stream<String> get stdoutLines;   // 按行解码
     Future<int> get exitCode;
     String get stderrTail;            // 环形截断，失败诊断用
     void kill();                      // 幂等
   }
   Future<RunningProcess> start(executable, args, {environment});
   ```
   `SystemProcessRunner.start` 落 `Process.start`；kill 用 `Process.kill()`（平台默认信号）。
2. `FfmpegVideoExportService.concat` 增流式路径：args 加 `-progress pipe:1 -nostats`，
   解析 `out_time_ms=`（μs，注意 ffmpeg 该键实为微秒）→ `progress = outTimeUs / (Σ所选
   duration_ms × 1000)`，clamp 0..1 且单调不回退；duration 缺失 → indeterminate。
   接口签名扩 `onProgress` 回调 + `CancelToken`（轻量自建，含 isCancelled + onCancel 钩子）。
3. 取消 = `kill()` → 等 exitCode → `_deleteIfExists(outputFile)` 清半成品 → 抛
   `CancelledError`；Windows kill 后句柄释放时序风险：删除失败仅 log（卡面风险条）。
4. 对话框：busy 态从 indeterminate 改「determinate 进度条（有分母时）+ 取消按钮」；
   失败提示从 SnackBar 改**对话框内嵌 InkErrorBanner**（债144①）；输出名校验处
   若 `exports/<name>.mp4` 已存在显示「同名文件将被覆盖」警示行，不阻断（债144②最小案）。
5. 备份/还原不动（PR-2 才接）；`run()` 既有消费方零改动。

**验收**：fake RunningProcess 单测锁参数序列（含 -progress pipe:1 位置）+ 进度解析
（乱序行/垃圾行/回退值防御）+ 取消路径（kill 调用、半成品删除、CancelledError 语义、
已成功不误删）+ 对话框 widget 测（进度渲染/取消按钮/内嵌 banner/覆盖警示）；
`TEST_FFMPEG=1` 真 ffmpeg 集成测跑通拼接与取消各一条；ARB 新键 en/zh 同步。

**风险**：`-progress` 输出节奏与平台差异——解析器按键值行宽松匹配，未知行忽略。

## PR-2：备份/还原接超时+kill（债153）

**做法**：pg_dump（备份）与 pg_restore（还原）改走 `start()` + 看门狗定时器
（备份 10min / 还原 30min，常量集中在服务内）；超时 → kill → 备份路径仅 warn 不阻断
（保持 LB-10「失败绝不阻断启动」不变量），还原路径抛错进现有失败面（`--single-transaction`
已保证 kill 后无半状态，现场核实 database_restore_service 现有参数后如缺则补）。
**验收**：fake 进程挂死场景单测两条（备份超时仅 warn / 还原超时报错）+ 现有测试全绿。

## PR-3：GA-1/2/7 画廊视频缩略图+播放（卡面照抄，零决策）

**做法**：`GalleryItem` 加 `thumbnailRelativePath?`（freezed 定向重生成，PLAYBOOK §2.2
`--build-filter`）；controller 透传 `node.thumbnailUrl`（batch slot 路径同查）；tile：有图 →
`Image.file` + errorBuilder 回退现图标 + 播放角标叠加，时长角标既有 `durationMs` 渲染 mm:ss；
点击视频 → `resolve`（canvas 双参根，不变量#4）+ `existsSync` 守卫 → `showVideoLightbox(context,
videoPath: 绝对路径)` → 缺失显 broken 态。GA-7 = 新生成视频 tile 显时长的回归断言。
**验收**：controller 透传测试、tile 三态（有图/回退/broken）widget 测、lightbox 调用测。

## PR-4：GA-3 筛选/搜索 + GA-4 存为角色（卡面照抄）

**做法**：`gallery_filter.dart` StateProvider 手写模型 `{kind, canvasId?, query}`；
SegmentedButton（全部/图片/视频）+ 画布下拉 + 搜索框（匹配 canvasName；prompt 搜索明确
non-goal）；纯内存过滤派生 provider；空结果复用现 empty 态 + 「清除筛选」按钮。
GA-4：仅 image 项出「存为角色」菜单 → 命名对话框（仿 `_NameDialog` 模式）→
`charactersController.createFromImage(name, absPath)`（补偿逻辑已有）→ 分捕
LocalIOError/DatabaseError/CancelledError 三类。ARB 新键 en/zh 同步。
**验收**：过滤逻辑纯函数单测（组合矩阵）+ widget 测（筛选交互/空态/存为角色 happy+error）。

## PR-5：CH-1 视频角色注入（卡面照抄，有三条执行者禁令）

**做法**：`generation_controller.dart` `_injectCharacterRefs`（现 L667 门
`nodeType != 'image' → return`）改双分支：image 保持现规则（maxRefImages>0 且
imageToImage）；**video 分支仅要求 maxRefImages>0——不得检查 modes；不得顺手加
mode∈caps.modes 校验**（卡面明令）；注入后 mode 推断沿现逻辑（推断为 imageToVideo）。
**验收**（卡面照抄）：r2v/omni caps 的 fake 断言注入且 **mode==imageToVideo**；
i2v（maxRefImages=0）零注入；image 路径回归不变。

## PR-6：MOD-1 OpenAI gpt-image 升级（死线 2026-10-23）

**做法**：先联网调研后继模型（卡面预期 gpt-image-1.5/2）：模型 ID、size 档、参数差异
（response_format/b64_json 行为、seed、n-max）、价格（CostModel 同步）。契约无大变 →
升 `kOpenAIModel` + capabilities + 测试基线 + PROVIDER-API §对应节；形态大变（如改异步）→
**停手回报**，本卡升级为 L 另立设计。openai_compatible 模板的 size 交集注释同步核对。
**验收**：契约测试全绿 + 手工真 key 冒烟一张图 + PROVIDER-API/成本表同步。

## PR-7：LB-24 代理 P0（卡面 P0 段照抄）

**做法**：dio 共享实例的 `HttpClient` 配 `findProxy`：读 `HTTPS_PROXY`/`HTTP_PROXY`/
`NO_PROXY`（大小写双查，Windows 惯例），实现为**纯函数** `proxyRuleFor(url, env)`（可注入
env map）供单测；`NO_PROXY` 支持逗号分隔 host 后缀匹配。SETUP.md 加「网络代理」节
（中文用户连 OpenAI/Gemini 场景 + TLS 拦截告警文案风险提示）。设置页代理区 = P1 不做。
**验收**：findProxy 纯函数矩阵单测（有/无环境变量、NO_PROXY 命中/未中、大小写）+
手工真代理冒烟一次。

## PR-8：框架债小件簇（可拆两 PR 落）

1. **atomicZipWrite 共享件**（债156）：抽 `atomicZipWrite(targetFile, build)` —— `.partial`
   写 + rename + 自吞排除（#188 P2-5）内置；LB-10/11/18 三处换用（import 侧 zip 面不动，
   等 LB-12 同窗条款失效即此卡收）。逐字对照三处现实现防语义漂移（fake 与真实现双测）。
2. **heavyOperationBusyProvider 归一**（债158）：导入/还原/导出（项目级）三 busy 位
   归一 provider；还原/导出入口反向补查导入 busy。
3. **建点视口中心**（债150）：新节点落点从固定世界 (200..600) 改视口中心换算，
   FAB/命令面板/空态三入口同修。
4. **restore_last_session 守卫扩宽**（债145）：从「只查 currentCanvasId」扩为
   「用户已发生任何导航即放弃恢复」（现场核实导航信号源后定实现位）。
**验收**：每件独立测试；BOARD 债表四行随 PR 打勾。

## 执行规程（每个 PR 一致，PLAYBOOK §1）

- main 切分支 → **TDD 先红后绿** → 自查闸门四条（flutter 用绝对路径
  `C:\Users\Kerro\flutter\bin\flutter.bat`；golden 3 个 Windows 假阳性白名单；ARB 齐平；
  git status 干净）→ **对抗评审 + 独立复跑**（subagent 两路，输出 findings+verdict）→
  P1 全修/P2 低成本全修 → conventional commit → PR → CI 全绿 → squash。
- freezed 模型改动一律 `--build-filter` 定向生成（PLAYBOOK §2.2，全量 build_runner 禁跑）。
- BOARD 同步：每 PR 合入时在近期落地表加行、对应债行打勾；MASTERPLAN 对应卡标记。

## 波次出口

8 个 PR 全绿合入；BOARD 债表 143/144/153/156/158/150/145 七行收口；M4 的 GA-1/2/3/4/7、
CH-1、EX-3、MOD-1 八卡打勾；LB-24 P0 段落地。剩余打磨欠账（EX-1′/EX-2/GA-5/6/SB 线/
AG 二期/CH-2/MOD-3）连同 D-M4 系待拍板项，波次收尾时汇总一次给用户拍板。
