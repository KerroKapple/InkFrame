# Architecture Drift Audit — Bucket B 决策记录

> 来源：`architecture-drift-2026-05.md`（PR #89）
> 决策日期：2026-05-13
> 决策人：@KerroKapple
> 用途：解锁 follow-up PR-D1/D2/D5/D7/D8，避免代码与文档反复横跳

## 决策清单

| ID | 议题 | 决策 | 落地 PR |
|----|------|------|---------|
| **D-1** | §2.1 @Riverpod codegen vs plain Provider | **文档跟代码**：ARCH 改为 plain Provider 风格 | PR-D2 |
| **D-2** | §1.3 feature 间互相 import | **提升共享代码到 core/services + custom_lint 加 import 边界规则** | PR-C-import-rule（新立）|
| **D-3** | §11.1/§11.4 A11y 整段半成品 | **移 ROADMAP P0-Beta**；ARCH §11 改为"计划中"现状描述 | PR-D7 |
| **D-4** | §12.1/§12.4 覆盖率门槛 + tag | **ARCH 改全仓 70%（跟 CI 实际）**；tag 名称对齐 | PR-D5 |
| **D-5** | §14.2/§14.4/§14.5 release pipeline 整段虚构 | **移 ROADMAP P0-Beta**；ARCH §14 改为"手工 release，自动化排期 beta 前" | PR-D8 |
| **D-6** | §6.1 schema 相对路径约束 | **应用层强制**：ARCH 标注 FileResolverService 是唯一执行点，DB 层不加 CHECK | PR-D1 |

## 解锁后的 PR 排期

### First wave 剩余（按 ROI 排序）
1. **PR-D3** — §4.1 错误体系全表重写（Top-N #2 Critical，~1h，**不依赖决策**）
2. **PR-D6** — §8/§9 i18n + 密钥文档（~45min，**不依赖决策**）
3. **PR-D4** — §5.1 并发文档 + cancel O(1) invariant（~30min，**不依赖决策**）

### Second wave（决策解锁，可并行）
4. **PR-D1** — §6.1 schema 路径约束文档修订（D-6 解锁，~10min）
5. **PR-D2** — §2.1 Riverpod 风格文档修订（D-1 解锁，~20min）
6. **PR-D5** — §12 覆盖率门槛文档修订（D-4 解锁，~10min）
7. **PR-D7** — §11 A11y 章节改"计划中"+ ROADMAP 加 P0-Beta（D-3 解锁，~20min）
8. **PR-D8** — §14 release pipeline 改"手工 + 排期"（D-5 解锁，~30min）

### 代码侧 PR（独立排期）
9. **PR-C2** — ink_gradient_button 6 色迁入 tokens.dart（~1h）
10. **PR-C3** — custom_lint 加 `ref.watch in build` 规则（~3h）
11. **PR-C-import-rule** — D-2 解锁：提升 generation_controller 共享 + custom_lint feature import 边界规则（~3h）

### 已完成
- ✅ **PR-C1**（#92）— LoggerService redact `password` / `proxy_password` / `secret`
- ✅ **PR-89 §附.6 amend** — invariant false positive 修订

## 后续维护

- 每个 follow-up PR 在 description 里引 entry ID（§x.y）+ Closes #88 子任务
- 全部 follow-up 合完后，把 `architecture-drift-2026-05.md` 标 `STATUS: RESOLVED`
- 本文件保留作为决策审计 trail，不随 audit 报告删除
