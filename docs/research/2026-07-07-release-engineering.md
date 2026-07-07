# 调研存档:发布工程(签名/更新/合规/遥测/内嵌 PG)(2026-07-07)

> 上线发布工程调研的完整原始报告。行动项见 `docs/MASTERPLAN.md` §5。来源附文末。

## 1. 签名与公证

### macOS(Developer ID + notarytool)
- 基线:Developer ID Application 证书签 app/dylib/CLI;公证只接受 ZIP/DMG/pkg;必须 Hardened Runtime
  (`codesign -o runtime`);公证后 `xcrun stapler` 装订;altool 已死用 notarytool。$99/年。
- **macOS 15 Sequoia 起右键"打开"绕过 Gatekeeper 的路径已移除**——未公证 app 要用户进系统设置两步
  "Open Anyway",公开分发公证事实上不可选。
- **坑(对 InkFrame 尤其致命)**:嵌套二进制(内嵌 PG 全套 exe/dylib + media_kit 的 libmpv)**每个
  Mach-O 都必须单独签名**并带 hardened runtime,inside-out 顺序,不要依赖 `--deep`;签名后再改 bundle
  内容=作废(注意 Flutter 构建后处理顺序);公证服务偶发卡数日,发布留缓冲。

### Windows(2024 后格局已变)
- **EV 证书不再免 SmartScreen**(微软官方 2026-05 文档明说"付 EV 溢价只为跳过 SmartScreen 已不合理")。
  EV/OV 首次下载行为相同:警告+攒信誉("几周+数百次干净安装");同一证书延续信誉,不签名则每版本从零。
- **Azure Trusted Signing 已改名 Azure Artifact Signing**:$9.99/月 Basic,无硬件 token,原生接
  GitHub Actions;**但组织限美/加/欧盟/英国,个人只限美/加——中国个人开发者不可用**。
- **开源低价通道:Certum Open Source Code Signing**,首年约 €69(含智能卡),续期 €29-30/年,
  限个人+需证明开源项目参与——对 InkFrame 是现实选项。
- 包格式:开源 Flutter 主流 = **Inno Setup EXE + winget/Scoop + brew cask**(LocalSend 样板);
  MSIX 主要为商店;**Microsoft Store 分发由微软重签,完全免 SmartScreen**(远期可考虑)。
  新工具 winapp CLI(2026-01,preview)有 Flutter 专属指南,值得跟踪。

### Flutter 桌面治理变化
- **Google I/O 2026:Canonical 成为 Flutter desktop(Win/mac/Linux)lead maintainer**;多窗口已落地,
  Impeller 年内推桌面。桌面端不再是弃儿,但路线图话语权转移,关注 Canonical 节奏。

## 2. 自动更新

| 方案 | 机制 | 评估 |
|---|---|---|
| 不做自更新(包管理器托管) | GitHub Releases + winget/Scoop/brew | **开源 Flutter 桌面主流现状(LocalSend/AppFlowy)** |
| auto_updater(leanflutter) | Sparkle/WinSparkle + appcast.xml + EdDSA | 最成熟的真自更新;想做时首选 |
| velopack(+flutter 桥) | Rust,安装器+增量一体,GitHub Releases 直连 | 桥是第三方 v0.2.x,引入 Rust 依赖;增量需求出现再评 |

**推荐**:首发走 LocalSend 模式——Releases 唯一真源 + winget + brew cask,应用内只做「检查新版本」
跳转;真自更新是签名之外的又一攻击面与维护负担,后置。

## 3. ffmpeg 合规

- **现行「外部探测不打包」是许可上最干净的方案**:GNU GPL FAQ(MereAggregation)明确 exec+命令行参数
  是独立程序通信,调用方不受 GPL 约束;InkFrame 的 concat demuxer+stream copy 用法完全在安全区。
- 若将来打包:LGPL 构建(无 x264)需署名+同服务器提供源码+不混淆重命名;GPL full 构建仅当自身 GPL
  兼容(LosslessCut/Shutter Encoder 都是自身 GPL 才敢打包)。
- winget 依赖机制有实锤缺陷(issue #2202/#4679)——不能只靠依赖声明,**保留运行时探测+缺失提示**
  (已具备);brew cask 的 `depends_on formula: "ffmpeg"` 成熟,建议声明。
- ⚠️ **既有义务警报(上线前必办)**:media_kit_libs_video **已经在分发 FFmpeg 衍生库(libmpv 构建)**。
  media-kit 的 darwin 构建自述"播放兼容商用、编码构建走 GPL",但 libs 包确切许可 README 不写——
  **必须核实实际拉取的构建变体,并按 LGPL 补齐署名+源码指引**(关于框注明 libmpv/FFmpeg+构建仓库链接)。

## 4. 遥测(local-first 立场)

- 社区敏感度依旧极高(2025 claude-task-master Sentry 默认全量 PII 事件为反面教材;正面范式:
  Notesnook opt-in、Ubuntu Insights opt-in+schema 公开+零 PII)。opt-in 参与率常 <3%,信任型产品吞下这代价。
- **推荐**:默认零上报(「不发任何网络请求」本身是卖点级信任资产);仅 **opt-in 崩溃报告**
  (范围只到 crash/error,显式 scrub,首启/设置页明示);若要用量数据用 **Aptabase**
  (隐私优先、可自托管、官方 Flutter SDK、无设备指纹)。绝不 opt-out 默认开。

## 5. 内嵌 PostgreSQL 分发

- 有先例但小众(Odoo Windows 捆绑 PG「测试/单用户便利」;zonky 精简构建 ~10MB 被 Electron 生态生产内嵌;
  PGlite/WASM 是 local-first 圈当红但对 Dart 桌面非现成替代)。继续全量 PG 路线可行,属少数派。
- **杀软是最高风险项**:PG 官方 wiki 明确要求排除数据目录与 postgres.exe;Defender 有把 PG 事务日志
  误判隔离致库损坏的实案;"用户可写目录启动未签名 initdb/postgres 链式起进程"是启发式引擎典型可疑画像。
  要点:**用自己的证书把每一个 exe/dll 签掉**;数据目录放 %LOCALAPPDATA% 并在文档写明 Defender 排除建议;
  预期部分企业 EDR 工单。
- macOS 公证:PG 几十个可执行+dylib 逐个 `codesign -o runtime`(CI inside-out 脚本化);数据目录写
  Application Support(bundle 内不可写且写了破签名);常规运行无需特殊 entitlement(无 JIT 构建)。
- 其他:Windows PG 只能 TCP 127.0.0.1(防火墙首启弹窗+端口冲突处理);macOS 可 unix socket 免网络面;
  postmaster.pid 崩溃残留自愈路径要有(app_teardown 已有序关停,补"上次未清理"恢复)。

## 来源(节选)

signing:learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation(2026-05)、
azure.microsoft.com/products/artifact-signing、certum.store/open-source-code-signing、
developer.apple.com/documentation/security/notarizing-macos-software-before-distribution、
developer.apple.com/news/?id=saqachfa(Sequoia);Flutter:docs.flutter.dev/deployment/*、
learn.microsoft.com/windows/apps/dev-tools/winapp-cli/guides/flutter、omgubuntu(Canonical 接管);
updates:pub.dev/packages/auto_updater、sparkle-project.org、github.com/velopack、github.com/localsend;
ffmpeg:ffmpeg.org/legal、gnu.org/licenses/gpl-faq(MereAggregation)、github.com/media-kit/libmpv-darwin-build、
winget-cli issues #2202/#4679;telemetry:blog.notesnook.com/telemetry-opt-in-vs-opt-out、
github.com/eyaltoledano/claude-task-master/issues/1681、github.com/aptabase/aptabase;
PG:odoo.com/documentation(捆绑 PG)、github.com/zonkyio/embedded-postgres-binaries、
wiki.postgresql.org(AV 排除)、github.com/electric-sql/pglite。

**未查到/需自行核实**:media_kit_libs_video 实际构建变体与 LICENSE(上线前必办);知名桌面产品内嵌全量 PG
的第一手公证复盘;Azure Artifact Signing 地域扩展时间表;winget 依赖修复时间表。
