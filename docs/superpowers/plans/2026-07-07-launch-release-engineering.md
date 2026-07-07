# 上线规划:发布工程与上线运营任务卡(2026-07-07)

> MASTERPLAN §5 的明细。现状全部实测核实(非文档转述)。开工前先读 `docs/EXECUTION-PLAYBOOK.md`。
> 调研支撑:`docs/research/2026-07-07-release-engineering.md`(签名/更新/合规/遥测/内嵌 PG)。

## 0. 现状核实(2026-07-07 实测)

- 仓库已 PUBLIC(27★,Discussions/Issues 开);远端 tag 停在 `v0.1.0-alpha.9`。
- **release.yml 从未运行过**(含 workflow_dispatch 演练,零实跑记录);smoke.yml 在 main push 持续绿。
- alpha.9 Release 挂着**手工本地构建上传的 macOS arm64 DMG**(未签名未公证);**Windows 零安装物**。
- **alpha.2~.6 未标 prerelease → GitHub 把 alpha.6 显示为 "Latest"**(访客下载入口指向 4 月旧版)。
- `PG_ARTIFACT_BASE_URL` repo variable 未配 → CI 产物不含嵌入式 PG,干净机无法首启;
  macOS 有本地替代脚本(make-relocatable-macos.sh),**Windows 无等价物**。
- 签名脚本是**真实现非脚手架**但零实跑(缺凭据自动 SKIP 退 0);distribute_options.yaml 的 MSIX
  publisher 空置待证书 subject。
- 无 CHANGELOG.md(release 走 --generate-notes);无任何更新检查代码;无官网(homepageUrl 空)。
- **good-first-issue 池为 0**(全仓 open issue=0);bug 模板 Provider 下拉已漂移(列着未实现的
  即梦/Hailuo,缺 OpenAI/Stability/custom)。
- **政策冲突实锤**:CLAUDE.md 写 "NO migration scripts",但 `lib/storage/migrations/` 实际维护
  v1→v7 前向迁移链并对旧库增量执行;alpha.9 起有真实用户数据在外(→ 决策 QG-5)。

## 1. 打包(PKG)

### PKG-1 release.yml 首次演练(S,零依赖,立即可做)
- workflow_dispatch(build_only)→ 验证双平台 build+zip+artifact 闭环、签名步打印 SKIPPED、
  DMG 步 best-effort;修暴露的问题。验收:一次 dispatch 全绿,两 artifact 可下载解压启动。

### PKG-2 PG 二进制分发源(M,「干净机能装」第一硬前置)
- 方案 A(推荐,免用户动作):fetch-binaries.sh 加 upstream 模式——Windows 从 EDB 官方 zip 下载
  裁剪(bin+lib+share),macOS 在 runner `brew install postgresql@17`+make-relocatable;
  SHA256 锁进 manifest。方案 B:用户开 R2/S3 上传+配 PG_ARTIFACT_BASE_URL(→U3)。
- 验收:release 产物内 `postgres --version`=17.2(双平台);干净虚拟机首启 initdb 成功。
- 风险:EDB URL 变动(SHA256 锁死+失败硬报错)。

### PKG-3 macOS 签名+公证接入(S 模型侧,硬阻塞=U1)
- 脚本已就绪只差 secrets(§13.4 六个值);打 tag 演练→`codesign --verify`+`stapler validate`+
  干净 mac 双击直开。注意:嵌套二进制(PG 全套+libmpv)逐个签,`--deep` 的覆盖需实测
  (调研:inside-out 是正道)。

### PKG-4 Windows 安装物形态(M,决策=U6)
- **先实测 MSIX+内嵌 PG 兼容性**(容器化文件系统虚拟化 vs fork postgres+写 ~/InkFrame,
  本项目特有风险):开发者模式装→首启 initdb→数据落哪。不干净则转 Inno Setup
  (签名复用 sign-windows.ps1);无论哪种,alpha/beta 期保留 unsigned zip 兜底。
- 验收:干净 Win11 装→首启建库 ≤8s→重启数据在→卸载干净。

### PKG-5 用户安装文档(S)
- 新 docs/INSTALL.md(或官网页):下载表、Gatekeeper/SmartScreen 过渡说明(未签名期截图)、
  「首启自动初始化本地数据库,无需装 PostgreSQL」、视频导出前置(ffmpeg 装法+INKFRAME_FFMPEG)、
  数据目录位置与备份建议。验收:没读过代码的人按文档双平台装好+生成一张图。

### PKG-6 Release 列表卫生(XS,立即)
- alpha.2~.6 逐个 `gh api PATCH -f prerelease=true`;alpha.9 手工 DMG 的 body 加"未签名,右键打开"。
  建议用户过目。

### PKG-7 macOS x64/universal(XS 标注 / M 真做)
- alpha 期只标注 "Apple Silicon only";Intel 需求出现(issue)再加 macos-13 matrix(PG x64 套跟随)。

## 2. 发布流程(releaseFlow)

### alpha.10 SOP(可交弱模型逐条执行)

前提:`release-tag.sh` 守卫 #1=origin/main HEAD subject 必须 `release(v` 开头;守卫 #2=传入 SHA==HEAD。
当前 HEAD 是 docs commit → **必须先合一个 release PR**。

```
1  git checkout -b release/v0.1.0-alpha.10 origin/main
2  唯一 commit:pubspec version: 0.1.0-alpha.10+10(+可选 BOARD 里程碑行);
   subject 必须 = release(v0.1.0-alpha.10): M1/M2 收官 + M3 首切片
3  push + PR;CI 全绿;GitHub UI 用 Rebase & merge(保 subject 前缀)
4  取 merge 后 main HEAD 完整 SHA
5  bash scripts/release-tag.sh <SHA> v0.1.0-alpha.10 "<一句描述>"
   (自动:双守卫→annotated tag→push→gh release create --generate-notes --prerelease)
6  tag 触发 release.yml → 三 job 绿 → 产物自动附加(幂等)
7  人工润色 notes:按 BUILD-RELEASE §11.3 结构重排 ROADMAP「未打 tag」段
   (Highlights/Features/Fixes/Breaking=schema v7 说明/Known Issues)
8  (签名就绪前过渡)维护者 mac 本地:make-relocatable → build → create-dmg →
   gh release upload(复制 alpha.9 手工路径)
9  验证:资产齐/prerelease √/干净机可启动/smoke 绿
10 ROADMAP untagged 块移入 Shipped 表,开下一 PR
```
失败处置:守卫 #1 挂=合并方式丢前缀→补空 release commit;守卫 #2 挂=重取 SHA。
回滚遵循 BUILD-RELEASE §12(不删 tag,forward-fix only)。

### beta(v0.1.0-beta.1)准入(发布工程侧,叠加在已达成的代码 DoD 之上)
1 双平台安装物含 PG,干净机验收(PKG-2/4);2 macOS 签名公证生效(PKG-3/U1);
3 Windows 至少签名产物(PKG-4/U2);4 应用内检查更新(UPD-1);5 数据升级政策拍板+演练(QG-5/4);
6 回归清单 v2 双平台各一轮(QG-1);7 用户安装文档上线(PKG-5/WEB-1);
8 产品底线:M4 中至少 导出 UI+画廊 可用。

### 1.0 定义(建议)
功能:script→storyboard→generate→export 贯通;undo/redo;软删恢复 UI。
工程:检查更新稳定 ≥1 个 beta 周期;日志一键打包;Windows 签名信誉建立;真机 GPU 帧率基线达标;
无 P0/P1 open bug;beta 全周期零数据事故。运营:官网稳定;发布节奏公开;SECURITY SLA 演练过一次。

## 3. 更新(UPD)

### UPD-1 应用内「检查更新」(M,beta 前必做,零用户依赖)
- GitHub Releases API(`/releases?per_page=10`,含 prerelease),SemVer 比较含 prerelease 序
  (alpha.10>alpha.9,测试矩阵要全);About 区按钮+新版提示+url_launcher 开 Release 页;
  启动静默检查做成偏好开关(默认开,失败静默 INFO,**6h 节流**防匿名限流 60/h);
  错误走 NetworkError 体系。涉及:新 update_check_service(接口+DI)、about_section、ARB。
- 验收:旧版运行→检查→显示可用→打开页面;无网静默;偏好可关。

### UPD-2 updates.json 自动更新协议(L,**1.0 后**,依赖 U4 域名)
- §10 设计已备;触发条件:用户量让"打开下载页"成摩擦。

## 4. 质量门槛(QG)

### QG-1 发布级手动回归清单 v2(S 写 + 每次发布 0.5d 执行)
- t5-manual-regression(9 条纯视频)扩为 release-regression.md:安装/首启(initdb≤8s)、Key 管理、
  图像闭环(参考图/角色/批量 slot)、视频闭环、画廊/导出(含 ffmpeg 缺失呈现)、偏好/会话恢复、
  升级(接 QG-4)。每条标平台。控制 ≤40 条,超出转自动化。mac 侧执行依赖 U5。

### QG-2 双平台真机烟测矩阵(S)
- {mac arm64, Win11}×{安装物}×{首启/二启} 结果记进每次 release PR;smoke 脚本可加
  INKFRAME_PG_BIN 真 PG 模式(本地硬信号)。

### QG-3 性能基线复测:真 GPU 帧率(M)
- 现基线是 headless CPU 代理(perf-baseline.md 自注);新 integration_test 用 FrameTiming 采
  200/400 节点 pan/zoom 的 p90/p99,双平台各一次进文档,拍阈值(如 p99<33ms@200);
  不进 CI(无 GPU runner),挂 QG-1 手动步。超阈立「视口裁剪」卡。
- 风险:desktop integration_test 稳定性一般——允许人工采集不断言。

### QG-4 数据升级演练(M,依赖 QG-5 拍板)
- CI 侧:populated-DB 迁移测试(harness 建到 vN-1+种子全表数据→migrate→断言完整性,@Tags(['pg']));
  人工侧:留 alpha.9 的 ~/InkFrame 快照作夹具,每次发版新安装物指向副本启动。

### QG-5 ⚠️ 政策决策:Zero Backward Compatibility vs 用户数据(→ MASTERPLAN 决策区 D-4,必须拍板)
- 冲突:铁律写 "NO migration scripts",代码实际维护 v1→v7 迁移链且 alpha.9 有真实用户;
  连带 SCRAM 加固(BLOCKERS §3)被"只对新 initdb 生效"卡住覆盖面。
- 选项:**A(推荐)**=政策重定义为「单线前向迁移是唯一升级路径;禁的是降级/旧格式并行/僵尸 API」,
  迁移链转正配 QG-4,SCRAM 可对存量一次性 ALTER;B=字面执行(版本不匹配提示重置——公开测试期
  不可接受);C=alpha 期 B、beta.1 起 A 并承诺 beta→1.0 数据延续。
- 落地:改 CLAUDE.md(根+docs)/CONTRIBUTING/DATABASE.md;Release notes 模板加「数据兼容性」固定段。

### QG-6 发布 checklist 落地(S,立即)
- BUILD-RELEASE §9 分层为「现在就执行」vs「凭据就绪后追加」;release.yml publish job 加
  `sha256sum dist/** > checksums.txt`(零成本立即做)。

## 5. 官网(WEB)

### WEB-1 GitHub Pages 单页官网(M)
- 形态:`website/` 纯静态(复用 Amber Noir 视觉;不引前端框架)+ pages.yml;README=开发者入口,
  官网=用户入口。内容:Hero(定位一句+已有 hero-canvas.png/demo GIF)、三条价值主张、下载区
  (Releases API fetch latest prerelease,标注 alpha/签名状态/Apple Silicon only)、5 分钟上手、
  Provider 矩阵(与 README 同源)、FAQ(Gatekeeper/SmartScreen/数据在哪/备份/离线)、页脚。
- 验收:kerrokapple.github.io/InkFrame 可访问,repo homepage 指过去。域名(U4)后接 CNAME 一行。

### WEB-2 示例项目/模板画布(M,与 ON-1/ON-2 联动)
- 首启空态 CTA 一键生成预置节点图(结构+提示语,不含生成结果);模板以代码构造(走 repo API)
  而非死 JSON(防 schema 漂移);进阶 defer:设置页露出演示模式(等价 INKFRAME_FAKE_PROVIDERS)。

## 6. 社区(COM)

### COM-1 good-first-issue 池重建(S,发布前用户过目)
- 现成候选:slot 常量化、job_queue_panel 错误映射(若 GAP-8 删 panel 则换)、pollTimeout 消费或删、
  AsyncValue `.when`、ARB 双语 review、第三语言;格式复用 new-issue-drafts.md(#69-73 成熟模板);
  顺带把 ROADMAP Provider 表 9 条 Open 开成 help-wanted issue。验收:≥6 gfi + ≥5 provider issue。

### COM-2 Issue 模板对账(XS):bug 模板 Provider 下拉对齐 provider_registry 9 款+custom;
  版本示例更新;日志路径核对。

### COM-3 CONTRIBUTING 英文摘要(S;全译可开成 gfi 吃狗粮);声明中文为权威防双语漂移。

### COM-4 Discord:**暂不开**(27★/0 issue 体量是空房间负资产);Discussions 链接铺满;
  beta 后周活跃 >10 帖再评估(→U8)。

### COM-5 发布公告(S 刷新文案;渠道/时机/账号=用户侧 U9)
- promo-drafts.md 三套文案停在 alpha.8 时代,发布时刷新(版本/provider 数/截图);
  **公告等 PKG-3 签名完成再发**(引流撞上未签名安装物是负体验)。

## 7. 用户本人必办清单(userActions,按紧迫排序)

| # | 事项 | 阻塞 | 参考成本 |
|---|---|---|---|
| U1 | **Apple Developer 注册($99/年)→ Developer ID 证书 .p12 → app-specific password → 6 值进 GitHub Secrets** | PKG-3→beta#2 | 审核 1-2 天;操作 2-3h |
| U2 | **Windows 签名证书拍板+购买**:OV 软证书 PFX(~$100-200/年,脚本直接可用,SmartScreen 信誉慢慢攒)vs Azure Artifact Signing(~$10/月 CI 友好,**中国个人不可用**)vs Certum 开源证书(首年 ~€69,限个人+开源) | PKG-4→beta#3 | OV 1-3 天 |
| U3 | PG 分发源拍板:接受 PKG-2 方案 A 则**零动作**;选 B 开 R2 桶+配 variable | PKG-2 | A:0 / B:1h |
| U4 | (可选)inkframe.app 域名→GitHub Pages | WEB-1 增强、UPD-2 前置 | ~$15-20/年 |
| U5 | macOS 真机可持续访问确认(签名调试/手工 DMG/mac 侧回归都需要) | PKG-3、QG-1/2/3 | — |
| U6 | Windows 安装物形态拍板(建议看 PKG-4 的 MSIX+PG 实测再定) | PKG-4 | 一次讨论 |
| U7 | **数据升级政策拍板(QG-5 A/B/C)**——牵动铁律文本/SCRAM 覆盖/每次 schema PR 写法 | QG-4/5、SCRAM | 一次讨论 |
| U8 | Discord 开不开(建议暂缓) | COM-4 | — |
| U9 | 公告渠道/时机/账号 | COM-5 | — |
| U10 | alpha.10 放行:review release PR + notes 终稿 | SOP 3/7 | 0.5h |

**主干**:U1/U2/U3 三条互不阻塞的用户侧关键路径;**alpha.10 可以不等它们先发**(unsigned+手工 DMG,
复制 alpha.9 模式:PKG-1/6+QG-6+SOP 即可);**beta.1 被 U1+U2+(U3 或 PKG-2A)+UPD-1+QG-5 硬阻塞**。
模型侧可立即并行且零用户依赖:PKG-1、PKG-2A、PKG-5、PKG-6、QG-1、QG-4、QG-6、UPD-1、WEB-1、WEB-2、
COM-1、COM-2、COM-3。
