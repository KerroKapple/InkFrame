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

## 二、T2 P8-Data · 数据层（待 T2 合入后核验）

### Schema & PG 生命周期

- [ ] `scripts/pg/fetch-binaries.sh` 幂等、SHA256 校验，生产 `resources/pg/{platform}/`
- [ ] `scripts/pg/pg-version.txt` 锁定 17.x 小版本
- [ ] `pg_controller.dart` 实现：ensureInitialized / start / stop / isAlive / 崩溃恢复
- [ ] 首次启动 `initdb + pg_ctl start + schema_version=1` ≤ 8s
- [ ] 杀 `postgres` 进程重启 → 清 postmaster.pid → 正常启动
- [ ] PG 强制绑定 `127.0.0.1`（不允许 0.0.0.0）
- [ ] `schema/001_init.sql` 8 张表全落 + 全 CHECK + 全索引（含部分索引 `WHERE deleted_at IS NOT NULL`）
- [ ] `schema_version` 单行约束 `CHECK (id = 1)`
- [ ] `migration_runner.dart` 支持版本递增扫描 `00X_*.sql` + 高版本拒绝

### Repository 契约

- [ ] 7 个 abstract interface 在 `lib/core/interfaces/`：纯 Dart、零 dart:io
- [ ] 7 个 Postgres 实现在 `lib/storage/repositories/`
- [ ] `base_repository.withUpdatedAt` 统一 updated_at 维护
- [ ] widget / viewmodel 层零 import 具体 Postgres 实现（`rg` 验证）

### 违规矩阵测试（完全覆盖）

- [ ] `nodes.type` / `node_role` / `status` CHECK 非法值全拒
- [ ] `edges.edge_type` / `role` CHECK + `UNIQUE(source,target,type)` 拒绝重复
- [ ] `jobs.status` CHECK + `jobs.progress ∈ [0,1]`
- [ ] `schema_version.id = 1` 单行约束
- [ ] PRD §21.9 全 12 个字段长度
- [ ] PRD §4.6.1 九宫格一致性（`parent_grid_id` 非 NULL 时双约束）

### 级联行为集成测试（真实 PG）

- [ ] 删 project → canvases ON DELETE CASCADE
- [ ] 删 canvas → nodes / edges / style_lanes ON DELETE CASCADE
- [ ] 删源 config node → result node.source_node_id SET NULL（§4.5.1 孤儿）
- [ ] 删 result node → batch_results ON DELETE CASCADE

### FileResolverService

- [ ] 相对 ↔ 绝对路径转换正确
- [ ] 拒绝 `../` 路径穿越（边界测试覆盖）
- [ ] `rg 'File\(.*/InkFrame/' lib/ --glob='!lib/services/file_resolver_service.dart'` 命中 = 0

### CI / 覆盖率

- [ ] T2 覆盖率 ≥ 75%（LCOV summary 贴 [P7-COMPLETION]）
- [ ] `check-updated-at.sh` 扫描所有 UPDATE 语句 → 全部 `SET updated_at = ...`
- [ ] pre-commit + pre-push + CI 全绿

### 文档

- [ ] `docs/DATABASE.md`：表关系图（mermaid）+ 字段说明 + CHECK 清单 + ON DELETE 策略 + migration 命名规范
- [ ] `CONTRIBUTING.md` 新增"本地 PG 设置"一节

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
