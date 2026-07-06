# InkFrame 后端深度评审（多 agent + 对抗式验证）

- 日期：2026-06-24
- 方法：10 个并行批判性 reviewer（按子系统）→ 对 contested/critical 发现做对抗式验证 → 综合
- 范围：后端（storage / providers / services / core / generation 逻辑）。前端按用户决定暂不评审（将来重做）。

## 一句话结论

**后端不是"质量低"——它有一根扎实的脊梁（DI 纪律、sealed 错误模型、JobQueue 状态机、带脱敏的结构化日志、路径安全、ADR 纪律），值得保留并在其上加固。** 你的几条担忧只有一部分成立，且都指向**少数几个具体、可修的债**，不是烂地基。下面用证据分项回应。

---

## 对你四条判断的诚实回应（带证据）

### 「抽象不够好」——**部分成立**（这是最该修的方向）
- ✅ **真问题：仓储层全部返回裸 `Map<String, Object?>`**，没有类型化领域模型；列名是字符串、写错只能运行时炸（`fromRow` 里 `as` 强转）。这是 ADR-0003 的有意选择，但确实是你能感觉到的"抽象薄"的核心。**系统性，跨 7 个仓储。**
- ✅ **真问题：同步 provider（gemini/openai/stability）~40% 复制粘贴**（key 校验、inline cache、`_rand()`、Dio 构造、内容审核检测各抄 3 遍），没有 `SyncProviderBase`。对比异步 6 个 provider 共享 `DashScopeAsyncProviderBase`（做得很好）——同步侧没跟上。
- ❌ **被推翻：所谓"ISP 违规"**——把 provider 拆成 `Submittable/Pollable/Cancellable/KeyValidatable` 恰恰是 ISP 的正确做法，reviewer 的批评方向反了。
- 结论：抽象不是普遍差，而是**两处明确债**（仓储边界类型化 + 同步 provider 抽基类）。其余（interfaces/DI/错误层）实际做得好。

### 「逻辑差很多」——**被夸大**（核心逻辑其实稳）
- ✅ **真问题（最高优先）：多步写入无事务**。三处确认非事务：节点软删+级联软删边、项目+首画布创建、结果节点预建+job 创建+入队。任一中途失败留下不一致/孤儿。`postgres` 包**支持 `runTx`**（迁移 runner 已在用），所以是"该用没用"。
- ❌ **被推翻的"逻辑 bug"**（验证后证伪，单 isolate 无抢占式线程）：JobQueue cancel-vs-success 仲裁（用 affectedRows，健全）、`_Handle._complete` 双重完成（有幂等守卫）、`_track` 永久挂起（有 30min 轮询硬超时 + finally 取消订阅）、teardown 永久阻塞（AppDelegate 有 15s native 兜底）、rate limiter 饥饿（timer 在有等待者时会重排）、迁移 v1 FK"上了生产"（全新库首启原子跑完 v1→v4，永不停在 v1）。
- 结论：逻辑主要缺的是**事务完整性**，外加几个**边角**（下述）。不是"差很多"。

### 「性能差很多」——**对后端而言被夸大**（问题具体且局部）
- ✅ 真但局部：① 每次生成 `edges.listIncoming` 查两遍（重复 DB 往返）；② 启动孤儿恢复 N+1（每个 job 一条 UPDATE，可批量）；③ `jobs(canvas_id, created_at)` 缺复合索引；④ `SELECT *` 过度取列（耦合，非正确性 bug）；⑤ JobsRegistry 对"卡死的非终态 job"无上限（长会话内存增长）。
- ❌ 被推翻：`SELECT *` "列序变化导致映射错位"——映射按**列名**（`col.columnName`），列序无关，证伪。
- 结论：后端性能问题是**几个可定点修的热点**，不是全局差。你感到的"性能差"很可能主要来自**前端**（画布重建等）——而前端正要重做。

### 「质量不够高」——**喜忧参半，但脊梁好**
- 值得保留（KEEP）：sealed `InkError` 全类型化 + i18n key + retryable 白名单；Riverpod DI（零 `new ConcreteClass()`，接口/实现分离）；JobQueue 状态机（FIFO + 每 provider 配额 + 退避抖动 + cancel/success 仲裁 + 可中断 sleep）；结构化日志 + 密钥脱敏 + 磁盘预算；rate limiter 单调时钟令牌桶；路径安全校验；provider registry 缓存 + limiter 生命周期绑定；ADR 纪律。

---

## 真实问题清单（验证后保留，按优先级）

### P0 — 先修（正确性 / 核心抽象）
1. **多步写入事务化**（logic/correctness，系统性）。用 `pool.runTx` 包：节点+级联边软删（`canvas_nodes_controller.dart`）、项目+首画布（`studio_projects_controller.dart`）、结果节点+job 创建（`generation_controller.dart`）。需要把仓储改成可在同一 `TxSession` 上执行（注入 session 而非各自持有 pool），或提供 UnitOfWork。
2. **仓储边界类型化**（abstraction，系统性）。不必废弃 Map（ADR-0003），但：(a) 生成/手写 `schema_columns.dart` 列名常量，消灭字符串列名 typo；(b) 在仓储边界提供类型化 row 提取器（`asStringOrThrow` 等）或返回 freezed 领域模型，把 `fromRow` 散落的强转收敛到一处并明确报错。
3. **抽 `SyncProviderBase`**（abstraction）。把 key 校验、inline-cache poll、`_rand()`、Dio 构造、内容审核检测上移；gemini/openai/stability 各从 ~320 行降到 ~80 行。

### P1 — 次修（健壮性 / 性能）
4. **provider 响应解析加防御**（robustness）。所有 `(x as Map)['k']` 解析包 try → `ProviderError(providerInvalidResponse)`，避免远端 schema 漂移时炸成 `UnknownError`。
5. **性能定点**：① 生成路径 `listIncoming` 取一次复用；② 启动孤儿恢复改批量 UPDATE（`status = ANY(@from)`）；③ 加 `idx_jobs_canvas_created ON jobs(canvas_id, created_at DESC)`（迁移 v5）；④ JobsRegistry 给"卡死非终态 job"加硬上限/兜底淘汰。
6. **边角逻辑**：mode 推断在"有参考图但全部解析失败"时静默退化为 t2i/t2v——加 warn 日志；lane 查询失败静默退化也补 warn；孤儿 result 清理加有限重试（当前无重试，DB 抖动会留孤儿）。

### P2 — 打磨（低优先）
7. error code ↔ i18n key 编译期校验（生成 + CI 检查）；`SELECT *` 改显式列（过度取列 + 耦合）；慢查询计时日志（>100ms warn）；`ProviderCapabilities` const 加 `assert` 不变量；下行迁移（downgrade）给出友好退出（当前抛 SchemaMigrationError）。

---

## 误报清单（已验证证伪——别在这些上花时间）
- `SELECT *` 列序错位映射 → 证伪（按列名映射）
- rate limiter 等待者饥饿 → 证伪（有重排 + 测试覆盖）
- JobQueue cancel/success 状态分叉、`_complete` 双完成 → 证伪（仲裁健全 + 幂等守卫）
- `_track` 永久挂起 → 证伪（30min 硬超时 + finally 取消）
- teardown 永久阻塞 → 证伪（AppDelegate 15s native 兜底）
- 迁移 v1 FK/约束"上生产" → 证伪（首启原子 v1→v4）
- 多数"线程/isolate 数据竞争" → 不适用（Dart 单 isolate，无抢占）

---

## 建议节奏
按 P0→P1 推进，约 2 个 sprint 可把后端做到"可放心在其上长出新前端"的状态。P0#1（事务）和 P0#2（仓储类型化）是最高杠杆：前者堵住数据一致性，后者是你感到"抽象薄"的根因。前端在后端 P0/P1 落定后再开。
