# Technical Debt Log

> 记录不在当前 scope 但已发现的技术债。格式：
> `TD-编号 | 描述 | 发现时 | 影响 | 建议修复窗口 | Owner`

---

## T2 (2026-04-15)

### TD-001 — jobs.result_node_id 缺 ON DELETE SET NULL ✅ 已修复（schema v=2, 2026-04-21）

- **位置**：原 v=1 `lib/storage/schema/schema_v1.dart` `CREATE TABLE jobs` 段
- **修复**：schema v=2 `lib/storage/schema/schema_v2.dart` DROP + ADD CONSTRAINT，`jobs_result_node_id_fkey` 重建为 `ON DELETE SET NULL`
- **测试**：`test/storage/schema/cascade_test.dart` "删 result node → batch_results CASCADE" 已改为直接删 result，断言 batch_results CASCADE 清空 + jobs.result_node_id 置 NULL
- **v=1 历史**：保留字面量 NO ACTION，不回溯字面追改——升级路径走 MigrationRunner

---

## v0.1.0-alpha.7 Release (2026-04-22)

### TD-002 — release tag 脚本化时序隐患 ✅ 已修复（scripts/release-tag.sh, 2026-04-22）

- **现象**：alpha.7 发布时 release 流程一键脚本 `git pull --rebase origin main && git tag -a ... && git push origin <tag>` 内，`pull` 执行在 PR squash merge 落地 remote 之前——本地 `main` 还是 alpha.6 HEAD (297d977)，tag 打错位置并 push 到公网，GitHub release 内容 = alpha.6。
- **临时修复**：tag 已删除重建到 `b41d735`（PR #48 squash commit），release 已删除重建（2026-04-22 06:18:36 UTC）。
- **根因**：脚本假设「GitHub 点 Rebase & merge → remote main HEAD 更新」瞬时完成；实际操作与网络有秒级延迟，且用户点的是 Squash merge（违反 `CONTRIBUTING.md §69`），squash commit 落地时序更慢。
- **建议护栏**（下次 release 前必须加）：
  1. release 脚本 pull 后断言：`git log -1 --format=%s` 匹配 release PR 标题模式 `release(v*)`，不匹配 abort
  2. 或更稳：脚本接受 `<merge-commit-sha>` 入参，tag 直接打在该 SHA 上（跳过本地 main 同步的时序陷阱）
  3. 软约束：release PR 评审时 reviewer 必须盯 merge method，只点 "Rebase and merge" ——不改 repo 级 Pull Requests 设置（三种 merge 方法全留开），避免与 feature PR 的 Squash merge 规矩打架
- **Owner**：下次 release 起手前由操作人加；Branch Protection 由仓库 admin 在 GitHub UI 设置
- **关联**：`CONTRIBUTING.md §69`（Rebase & merge 强制条款），PR #48（事故 release）
- **修复 (2026-04-22)**：`scripts/release-tag.sh` 落地，护栏 #1（PR 标题断言，exit 10）+ 护栏 #2（SHA 入参，exit 11）以强断言形式实现。CONTRIBUTING §Tag & Release 已改为脚本优先 + 手工兜底。集成测试 `test/scripts/release_tag_test.sh` 覆盖 17 个断言：arg 校验、guardrail negative、happy path（prerelease + stable）。护栏 3（软约束 reviewer 盯 merge method）保留为人肉约定，不改 repo 级设置以避免与 §67 打架。

---

## S4 (2026-06-11)

### TD-003 — VideoNodeBody thumbnail/play widget test 挂死 ✅ 已修复（test only, 2026-06-11）

- **位置**：`test/features/canvas/widgets/video_node_body_test.dart` 后两个 testWidgets（broken_image / play_circle），曾标 `skip: true`。
- **原 skip 注释（误诊）**：声称「widget test 进入 `fileResolverServiceProvider` 后 pump 不收敛，挂死 20min+」。
- **真实根因**：与 `fileResolverServiceProvider` / pump 无关。挂死发生在测试 setup 第一行 `await Directory.systemTemp.createTemp(...)`——在 `testWidgets` body 内 `await` 真实 `dart:io` 异步 Future，其完成回调被调度到 binding 控制的事件循环但永不被抽水，`await` 永久阻塞。隔离实验证实：同一 `createTemp` 在 plain `test()` 内秒过，仅在 `testWidgets()` body 内挂死；`createTempSync()` 在两种 test 内均秒过。
- **修复**：两个 test 的 setup 改用同步文件 API（`createTempSync` / `createSync` / `deleteSync`），并去掉无谓的 `await paths.ensureInitialized()`（resolver 只做 `existsSync()`，父目录不必预建）。断言意图不变（broken_image / play_circle）。
- **教训**：`testWidgets` body 内禁止 `await` 真实异步 `dart:io`；一律用 `*Sync` 变体（确需异步时应包 `tester.runAsync`，但本次未走该路径）。

