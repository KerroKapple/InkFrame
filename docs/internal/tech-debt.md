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

### TD-002 — release tag 脚本化时序隐患 ⚠️ 已临时修复，护栏未加

- **现象**：alpha.7 发布时 release 流程一键脚本 `git pull --rebase origin main && git tag -a ... && git push origin <tag>` 内，`pull` 执行在 PR squash merge 落地 remote 之前——本地 `main` 还是 alpha.6 HEAD (297d977)，tag 打错位置并 push 到公网，GitHub release 内容 = alpha.6。
- **临时修复**：tag 已删除重建到 `b41d735`（PR #48 squash commit），release 已删除重建（2026-04-22 06:18:36 UTC）。
- **根因**：脚本假设「GitHub 点 Rebase & merge → remote main HEAD 更新」瞬时完成；实际操作与网络有秒级延迟，且用户点的是 Squash merge（违反 `docs/CONTRIBUTING.md §69`），squash commit 落地时序更慢。
- **建议护栏**（下次 release 前必须加）：
  1. release 脚本 pull 后断言：`git log -1 --format=%s` 匹配 release PR 标题模式 `release(v*)`，不匹配 abort
  2. 或更稳：脚本接受 `<merge-commit-sha>` 入参，tag 直接打在该 SHA 上（跳过本地 main 同步的时序陷阱）
  3. 软约束：release PR 评审时 reviewer 必须盯 merge method，只点 "Rebase and merge" ——不改 repo 级 Pull Requests 设置（三种 merge 方法全留开），避免与 `dev` 的 Squash merge 规矩 §67 打架
- **Owner**：下次 release 起手前由操作人加；Branch Protection 由仓库 admin 在 GitHub UI 设置
- **关联**：`docs/CONTRIBUTING.md §69`（Rebase & merge 强制条款），PR #48（事故 release）

