# LB-18 日志目录入口 + 诊断包 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 设置页两按钮——「打开日志目录」+「导出诊断 zip」（logs/* 含 pg.log、crashes/*、config 白名单两文件、版本信息），红测钉死包内无 api_key。

**Architecture:** `ZipDiagnosticsBundleService`（借 LB-11/22 落盘纪律：.partial→rename、失败清理抛 LocalIOError；archive 依赖已在）。**config 目录只白名单 `preferences.json`/`custom_providers.json` 两个文件、绝不整扫**——macOS Debug 的 `config/secrets.dev.json`（明文 key）由白名单结构性排除，红测种一个带 api_key 的 secrets.dev.json 证明排除生效。`crashes/*` 为卡面外的有意添加（crash 文件按 LB-17 设计无 context/extra、天然无敏感，诊断价值高）。UI=新 `DiagnosticsSection`（打开日志目录复用 folderOpenerProvider；导出复用 LB-11 的 `saveLocationPickerProvider` seam）。

**Tech Stack:** archive（已有）、FolderOpener、Riverpod。

## Global Constraints

- 分支 `feat/lb-18-diagnostics`；conventional commits；每 commit `flutter analyze lib test` + `flutter test --exclude-tags golden`。
- 注释中文；ARB en+zh 同 commit + gen-l10n；零硬编码样式；InkError 链；plain test() 做真 IO；跨 await 依赖首个 await 前 read（#188 P1-1）。
- zip 内路径统一 `/`；`pg.log` 位于 `<root>/logs/` 下，logs/* 全扫覆盖，无需单列。

### Task 1: DiagnosticsBundleService（接口+实现+红测）

**Files:** Create `lib/core/interfaces/diagnostics_bundle_service.dart`、`lib/services/diagnostics_bundle_service.dart`；Test `test/services/diagnostics_bundle_service_test.dart`

**Produces:** `Future<void> exportBundle({required String targetPath})`；纯函数 `String diagnosticsBundleFileName(DateTime utc)` → `inkframe-diagnostics-YYYY-MM-DD-HHMMSS.zip`。

- [ ] 红测：①内容清单——种子 logs/{app.log,pg.log}、crashes/inkframe.crash.1.log、config/{preferences.json,custom_providers.json,**secrets.dev.json(含 "api_key" 字段)**} → zip 恰含 info.json + logs/×2 + crashes/×1 + config/×2，**无 secrets.dev.json**；②核心红测——遍历包内全部条目字节断言不含 `"api_key"` 子串；③info.json：appVersion/schemaVersion=kAppMigrations.last.version/platform/createdAtUtc；④空目录→仅 info.json；⑤目标不可写→LocalIOError 且零 .partial 残留；⑥文件名纯函数。
- [ ] 实现（镜像 ZipProjectArchiveService 骨架：encoderOpen/cleanup/closeSync、兜底 catch 翻 LocalIOError；日志 module `diagnostics`）→ 跑绿 → Commit `feat(services): LB-18 诊断包服务——config 白名单排除 secrets,红测钉死无 api_key`

### Task 2: DI + DiagnosticsSection + l10n

**Files:** Create `lib/core/di/diagnostics.dart`、`lib/features/settings/widgets/diagnostics_section.dart`；Modify `settings_screen.dart`（BackupSection 后）、ARB ×2 + gen-l10n；Test `test/features/settings/diagnostics_section_test.dart`

ARB：`settingsDiagnosticsSection`（Diagnostics/诊断）、`settingsDiagnosticsHint`（Logs and configuration for bug reports — API keys are never included./日志与配置用于问题反馈——不含任何 API Key。）、`settingsOpenLogDir`（Open log folder/打开日志目录）、`settingsExportDiagnostics`（Export diagnostics…/导出诊断包…）、`settingsDiagnosticsExported`（Diagnostics exported/诊断包已导出）、`settingsDiagnosticsExportFailed`（Export failed/导出失败）。

- [ ] 红测：打开日志目录→FolderOpener.open(paths.logs.path)；导出→picker(建议名)→service 收到 path+成功 toast；picker 取消→零调用；service 抛 LocalIOError→失败 toast；busy 防重入。
- [ ] 实现（deps 首 await 前 read；busy 本地 flag）→ 跑绿 → Commit `feat(settings): LB-18 诊断区——打开日志目录 + 导出诊断包`

### Task 3: docs + 闸门 + PR + 对抗评审

- [ ] BOARD 近期落地行（#191 预写核验）+ MASTERPLAN §3 LB-17 行尾「LB-18 诊断包(待做)」→ ✅；全量闸门（Docker PG）→ push → PR → 对抗评审（重点：泄密面/白名单完备性/大日志内存）→ 修 P1/P2 → CI 真绿核验 → squash 合并。

## Self-Review

卡面覆盖：两按钮 ✓ / logs+pg.log+两 config+版本 ✓ / 红测无 api_key ✓ / archive 共享 ✓。有意添加：crashes/*（PR 声明）。留白：日志超大时整包体积（日志有 10MB 轮转上限，量纲可控）。
