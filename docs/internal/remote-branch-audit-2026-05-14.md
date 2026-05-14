# Remote Branch Audit — 2026-05-14

> 审计 origin 上未被 2026-05-14 分支收口工作覆盖的 7 条分支。范围只读，本文档只产出建议，不动手处置。
>
> 上游 plan：`docs/superpowers/plans/2026-05-14-branch-consolidation.md` (Phase E)

## Snapshot

| Branch | Ahead | Behind | Last commit | Author | Recommendation |
|---|---:|---:|---|---|---|
| `chore/docs-layout` | 7 | 53 | 2026-04-18 | kerro | **Delete** — docs/CLAUDE.md + CONTRIBUTING.md 已通过其他 PR 重新组织过 |
| `docs/git-linear-history` | 3 | 53 | 2026-04-15 | kerro | **Investigate** — "enforce linear git history" 内容是否仍有价值，对比 `docs/internal` 现状 |
| `docs/provider-api-and-adr` | 7 | 53 | 2026-04-17 | Kerro | **Delete** — merge of #4 provider-layer-skeleton；provider API/ADR 已在主线落地 |
| `docs/testing-and-build` | 9 | 53 | 2026-04-15 | kerro | **Investigate** — TESTING + BUILD-RELEASE docs；对比当前 docs 是否已覆盖 |
| `feature/canvas-ui-skeleton` | 11 | 53 | 2026-04-17 | kerro | **Delete** — P2.3 canvas skeleton；canvas 已被 T4 sprint + Amber Noir 重写多轮取代 |
| `feature/gemini-image-provider` | 5 | 53 | 2026-04-17 | kerro | **Delete** — P2.2 GeminiImageProvider；origin/main `lib/providers/gemini_image_provider.dart` 已是正式实现 |
| `feature/provider-layer-skeleton` | 12 | 53 | 2026-04-18 | Kerro | **Delete** — merge of #9 canvas-ui-skeleton；provider 骨架已被 ADR-0004/0005 + dashscope_async_provider_base 取代 |

## 共同特征

- 全部 last commit ≤ 2026-04-18，距今近 1 个月，期间 origin/main 推进了 53 个 commit
- 全部是 P1/P2 早期 sprint 分支，命名含 `feature/` `docs/` `chore/` 前缀
- 全部 behind 53——已被主线甩开两个 sprint（T3 → T4 → T5）

## 建议执行步骤（不属于本审计范围）

1. **逐条 spot-check**：对 "Investigate" 项跑 `git diff origin/main..origin/<branch> -- <relevant-path>`，确认无独立未取代价值
2. **批量删除 5 条 "Delete"**：`gh api -X DELETE repos/KerroKapple/InkFrame/git/refs/heads/<branch>`
3. **2 条 "Investigate" 决策后处置**：删除 / cherry-pick 剩余价值 / 直接 PR

## 不动手的理由

- 远程分支 owner 可能不是当前会话用户的认知边界（虽然全部 author 是 kerro）
- 删除远程分支是公开可见操作，blast radius 大
- Phase 0（本次收口）已闭环主要流血点；二级清理留给 Phase 1 路线图阶段决定
