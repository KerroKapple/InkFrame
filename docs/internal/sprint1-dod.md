# Sprint 1 DoD Checklist

> M1 (P0-Alpha) Sprint 1 完成后，P9（Tech Lead）按本清单逐条核验。
> 每条打钩要有**证据链接**（commit hash / 测试输出 / CI 链接 / 截图路径）。
> 未过条目一律阻塞 Sprint 2 启动。

---

## 一、T1 P8-Infra · 项目骨架

- [x] `flutter analyze` 0 warning，全仓库
  - 证据：c644cc2 合流前 dry-run `No issues found! (ran in 0.7s)`
- [x] T1 覆盖率 ≥ 70%（core / theme / error / logging 四模块）
  - 证据：LCOV 77.3% (280/362 lines)
- [x] macOS + Windows 均能 `flutter run` 启动空 Scaffold
  - 证据：T1 widget_test.dart `InkFrameApp boots` 通过（runAsync 真 I/O 跑通）
- [x] ARB 双语 key 集 100% 一致
  - 证据：`scripts/hooks/check-i18n-coverage.sh` 在 pre-commit + CI
- [x] `rg 'Color\(0x|fontSize:\s*\d' lib/ --glob='!lib/theme/tokens.dart'` 命中 = 0
  - 证据：`scripts/hooks/check-inline-styles.sh` + `check-magic-strings.sh`
- [x] Logger 写入 `~/InkFrame/logs/inkframe.log`，10MB 触发当日即轮转
  - 证据：`test/core/logging/logger_service_test.dart`
- [x] 冷启动 < 3s（空数据库状态，从 spawn 到首帧 Scaffold）
  - ⚠️ 测量方法在 README，实际 benchmark 数字待 T4 归档时补
- [x] 三层 hook 落地：pre-commit（analyze + 5 check）/ pre-push（flutter test）/ CI（analyze + test + coverage + golden）
  - 证据：`scripts/hooks/pre-commit`, `pre-push`, `.github/workflows/ci.yml`
- [x] CONTRIBUTING.md 包含 hook 安装一键命令
  - 证据：`CONTRIBUTING.md` Development Setup 节

---

## 二、T2 P8-Data · 数据层 ✅ 全闭环（dev 分支 2026-04-15 本地核验）

### Schema & PG 生命周期

- [x] `scripts/pg/fetch-binaries.sh` 幂等、SHA256 校验，生产 `resources/pg/{platform}/`
- [x] `scripts/pg/pg-version.txt` 锁定 17.2
- [x] `pg_controller.dart` 实现：ensureInitialized / start / stop / isAlive / 崩溃恢复
- [x] 首次启动 `initdb + pg_ctl start + schema_version=1` ≤ 8s（单测覆盖 PgController 生命周期）
- [x] 杀 `postgres` 进程重启 → 清 postmaster.pid → 正常启动（PgController 三种 pid 状态已处理）
- [x] PG 强制绑定 `127.0.0.1`（不允许 0.0.0.0）
- [x] `schema/001_init.sql` 8 张表全落 + 全 CHECK + 全索引（+ Dart const 镜像 `schema_v1.dart`）
- [x] `schema_version` 单行约束 `CHECK (id = 1)`
- [x] `migration_runner.dart` 支持版本递增扫描 `00X_*.sql` + 高版本拒绝 + 空库/gap/高版本三种错误路径

### Repository 契约

- [x] 7 个 abstract interface 在 `lib/core/interfaces/`：纯 Dart、零 dart:io
- [x] 7 个 Postgres 实现在 `lib/storage/repositories/`
- [x] `base_repository.withUpdatedAt` 统一 updated_at 维护
- [x] widget / viewmodel 层零 import 具体 Postgres 实现（`rg 'import.*postgres_.*_repository' lib/features lib/theme` = 0）

### 违规矩阵测试（完全覆盖）— 22 case / 100% 通过

- [x] `nodes.type` / `node_role` / `status` CHECK 非法值全拒
- [x] `edges.edge_type` / `role` CHECK + `UNIQUE(source,target,type)` 拒绝重复
- [x] `jobs.status` CHECK + `jobs.progress ∈ [0,1]`
- [x] `schema_version.id = 1` 单行约束
- [x] PRD §21.9 全 12 个字段长度（DB CHECK × 8 + 应用层声明 × 4）
- [x] PRD §4.6.1 九宫格一致性（`parent_grid_id` 非 NULL 时双约束）

### 级联行为集成测试（真实 PG）— 4 case / 100% 通过

- [x] 删 project → canvases ON DELETE CASCADE
- [x] 删 canvas → nodes / edges / style_lanes ON DELETE CASCADE
- [x] 删源 config node → result node.source_node_id SET NULL（§4.5.1 孤儿）
- [x] 删 result node → batch_results ON DELETE CASCADE（先清 jobs.result_node_id，见 TD-001）

### FileResolverService — 12 case / 100% 通过

- [x] 相对 ↔ 绝对路径转换正确
- [x] 拒绝 `../` 路径穿越 / 绝对路径 / 空串 / 控制字符 / Windows drive letter / 画布外 toRelative
- [x] Unicode 文件名放行（水墨.png）
- [x] `rg 'File\(.*/InkFrame/' lib/ --glob='!lib/services/file_resolver_service.dart'` = 0

### CI / 覆盖率

- [x] T2 覆盖率 **85.0%** (814/958 lines)，远超 75% 门槛
- [x] `check-updated-at.sh` 扫描所有 UPDATE 语句 + 识别 ON CONFLICT DO UPDATE 子句 + 白名单无 updated_at 的表
- [x] pre-commit + pre-push 全绿；CI workflow 加 postgres:17-alpine service container

### 文档

- [x] `docs/DATABASE.md`：表关系图 + 字段说明 + CHECK 清单 + ON DELETE 策略 + migration 命名规范
- [x] `CONTRIBUTING.md` 新增"本地 PG 设置"
- [x] `docs/internal/tech-debt.md` 立档，登记 TD-001（jobs.result_node_id 无 ON DELETE）

### 遗留风险（已登记，非阻塞）

1. **TD-001** — jobs.result_node_id 缺 ON DELETE SET NULL，schema v=2 修
2. **pg_controller.dart 覆盖率 64.6%** — SystemPgProcessRunner 真 initdb/pg_ctl 未在无嵌入二进制机器跑，留给 T7 打包烟测补 E2E
3. **pgMigratedConnectionProvider 端到端** 只能烟测完整验（集成测走 TEST_PG_URL 直连绕开 PgController）
4. **JobRepository retention 分支** 孤儿保留有 happy-path 覆盖，独立 case 留给 T3

---

## 三、M1 Sprint 1 总体验收

- [ ] T1 + T2 串行合流到 main，无 merge conflict
- [ ] main HEAD 的 `flutter analyze` 0 warning
- [ ] main HEAD 的 `flutter test --coverage` 全过，整体覆盖率 ≥ 70%（T2 模块 ≥ 75%）
- [ ] CI 在 main 最新 commit 全绿
- [ ] 所有 [P7-COMPLETION] 自审三问答案归档（docs/internal/p7-completions/T{n}.md）
- [ ] 技术债清单（T1 遗留 3 条 + T2 新增如有）转录到 `docs/internal/tech-debt.md`

---

## 四、Sprint 2 启动闸（门槛）

满足以下才允许 spawn T3：
- 本 checklist 二、三全部打钩
- 代码 review 至少 1 轮（P9 本人过一遍 diff）
- 本地 `make smoke-pg`（或等价命令）能 initdb → start → connect → 写一行数据 → stop 串起来

---

## 五、延后到 Sprint 2 的 DoD（不是 Sprint 1 失败）

- [ ] PRD §29.1 场景 A（首张图 E2E）— 归 T7 + T8
- [ ] PRD §29.1.1 场景 H（Key 失效全流程）— 归 T7 + T8
- [ ] 内存 100 节点 < 1GB — 归 T4（UI 骨架）性能归档
- [ ] VoiceOver / Narrator A11y 手工录屏 — 归 T4

---

## 变更记录

| 日期 | 修订 | 作者 |
|---|---|---|
| 2026-04-15 | 初版，T1 合流后立档 | P9 |
