# Road to Beta — 关键路径与验收清单

> ⚠️ **归档快照，不再更新**：本文冻结于 2026-06-11。§3 的 beta DoD 已于 2026-07-02 达成
> （见 [BOARD.md](BOARD.md) M2 表末行，CI run 28595968123 全绿）。现状唯一事实源见 [BOARD.md](BOARD.md)。
>
> 快照日期：2026-06-11 · 当前：`v0.1.0-alpha.9`（105 commits）
> 这份文档回答一个问题：**alpha → beta 还差什么，怎样算达成。**
> 与 `ROADMAP.md` 的关系：ROADMAP 列「方向与认领」，本文列「到 beta 的收口路径与 DoD」。

---

## 1. 现状快照

| 维度 | 状态 |
|------|------|
| 阶段 | alpha 收口期，核心创作闭环可运行 |
| 代码量 | `lib/` 145 个 Dart 文件 |
| 测试 | 96 个测试文件 / ~512 用例，绿（1 个 logger rotation 超时 flake，与功能无关，`--timeout 120s` 通过） |
| Provider | 7 个已上线（Gemini · Kling V3/Omni · Wanx ×4）；6 个 Open |
| i18n | en/zh key 集合 100% 对齐（已加回归守卫测试） |
| 已打通闭环 | canvas 建节点 → 生成 → JobQueue 状态机 → 落盘 → 渲染 |

**判断**：骨架成熟，无结构性硬伤。离 beta 的门槛**不是功能广度，而是质量基建（测试/性能/跨平台）**。

---

## 2. 到 Beta 的关键路径（按杠杆排序）

### P0 — 质量基建（beta 的真正门槛）
- [ ] **Golden test 落地**：当前 `golden` job 是占位 → 建立基线（需 Flutter 本机生成，已具备）。
- [ ] **E2E 主链路**：至少覆盖 生成 → 落盘 → 渲染 一条贯穿用例（script→storyboard→export 完整链可留到 beta 后）。
- [ ] **性能基线**：canvas 节点 > 200 的 frame drop 量化 + 阈值守卫。
- [ ] **Windows 烟测自动化**：macOS 已手动跑，Windows 缺 reproducible 流程。
  — 已补 `smoke.yml`（macos-14 + windows-latest：build + test + boot）与本地可复现脚本；待 CI 首跑验证。

### P1 — 广度铺量（收益高、可并行）
- [ ] **Provider 试点**：DALL-E（`openai-image`）+ Stable Diffusion（`stability-image-core`）——计划已就绪并预审（`docs/superpowers/plans/2026-06-10-provider-{dalle,stable-diffusion}.md`）。
- [ ] **Provider 第二波**：Runway / Pika / Luma（异步视频，复用现有 kling/wanx 形态）。
- [ ] **Midjourney**：无官方 API，**暂缓/降级**，不进 fleet。

### P2 — 收口项
- [ ] 设计 token 收尾（剩余 ~60 处硬编码样式，UI Sprint 3+）。
- [ ] Canvas 功能补齐（undo/redo 全覆盖、group/collapse）——改同一批文件，**需串行**，不适合并行 fleet。
- [ ] ARB 整顿 PR 合并（分支 `chore/arb-reconciliation` 已 push，待建 PR）。

---

## 3. Beta 验收清单（Definition of Done）

beta 资格 = 下列全绿：

1. [ ] `flutter analyze lib test` → `No issues found!`
2. [ ] `flutter test` 全绿（flaky 已隔离或修复）
3. [ ] Golden 基线存在且 CI 校验
4. [ ] 至少 1 条 E2E 主链路用例
5. [ ] Windows + macOS 双平台烟测通过（Windows 有 reproducible 脚本）
   — 流水线已落地：`.github/workflows/smoke.yml` + `scripts/smoke/{macos-smoke.sh,windows-smoke.ps1}`；待首次 CI 实跑绿后勾选。见 `docs/BUILD-RELEASE.md §13.1`。
6. [ ] 性能基线文档化（节点规模 vs 帧率阈值）
7. [ ] 覆盖率 ≥ 70%（ROADMAP 既定门槛）
8. [ ] 无 P0 级 open bug

> Provider 数量**不是** beta 门槛——是 beta 后持续铺量的方向。

---

## 4. 已知约束 / 阻塞

- **Provider fixture-E2E 需真实 API key**：`PROVIDER-API.md §12.3` 禁止手写 fixture，必须真实响应脱敏。无 key 时 provider 只能落到「code-complete + 单测 + 契约测试绿，fixture-E2E pending」。
- **PR 创建需 `gh auth login`**：`git push` 可用（凭据已缓存），但 `gh` 未登录，PR 这步需人工。
- **Flutter 不在 PATH**：本机 SDK 在 `C:\Users\Kerro\flutter`，命令走绝对路径 `flutter.bat`。

---

## 5. 当前最高杠杆动作（互不冲突）

1. **合掉 ARB 整顿 PR** — 清账（待 `gh` 登录）。
2. **放行 provider 试点 fleet** — 验证多-worktree 并行模式 + 拿下 DALL-E/SD 两款。
