# QG-4 数据升级演练 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 QG-4(beta.1 硬阻塞三件套之一):CI 侧 populated-DB 迁移测试 + 真二进制升级演练 E2E + 人工侧 SOP——证明「带数据的旧版工作区升级到新版,数据零丢失」。

**Architecture:** 三层递进。① CI 层(@pg,每次 PR 跑):从 v1 起**逐版本迁移、边迁边种子**,全链跑完后断言数据完整性 + 全表非空守卫 + 降级拒绝——任何未来 schema PR 若不补种子,守卫直接红,把 ADR-0012 的「每个 schema PR」纪律固化成闸门。② 真栈层(@realpg,发版前跑):同一数据目录先用截断链(v6)bootstrap 模拟「旧版应用」写入数据并关库,再用全链 bootstrap 模拟「新版应用」冷启,断言前向迁移 + 数据存活——这是对真实用户升级路径的最忠实模拟。③ 人工层:SOP 文档化(真安装物 + HOME 指向快照副本)。

**Tech Stack:** 复用既有资产——`kAppMigrations`(单一真相源,`sublist` 截断)、`MigrationRunner` / `DatabaseBootstrap(pool, migrations:)`(原生支持自定义链)、`PgController` + realpg 双门控模式(照抄 `test/e2e/real_pg_stack_e2e_test.dart`)、CI 已有 postgres:17 service + `TEST_PG_URL`。零生产代码改动,纯测试 + 文档。

**验收(≡ QG-4 卡原口径):** CI 侧 populated-DB 迁移测试入链(@pg,CI 自动跑)✓;真栈升级演练可一键复跑(@realpg)✓;人工侧 SOP 落文档 ✓。合入后 beta.1 阻塞名单只剩 U1/U2。

**关键设计决策(评审时重点看这三条):**
1. **种子在 v1 形态写入**(用当时存在的列,含后来被 v3/v4 删掉的 retry/next_poll 列的默认值)——让 v2..v7 每一条 ALTER 都在**有数据的表**上执行,这正是 QG-4 要防的风险面(空表上 ALTER 永远不会暴露数据问题)。
2. **全表非空守卫**查 `information_schema` 动态枚举——未来 v8 新增表若没同步补种子,本测试直接红;纪律不靠人记。
3. **悬空 cover_node_id 夹具**:v1 无 FK 时故意留一个悬空引用,断言 v3 的预清理 UPDATE 真的把它置 NULL 而好引用原样保留——迁移链里唯一一条「改数据」的语句必须有数据断言盯着。

---

### Task 1: CI 侧 populated-DB 迁移测试(@pg)

**Files:**
- Create: `test/storage/schema/populated_migration_test.dart`

- [ ] **Step 1: 写测试(先写全,红/绿看 Step 2 本地真 PG)**

```dart
// QG-4 CI 侧:populated-DB 迁移测试。
// 从 v1 起逐版本迁移,版本引入表时立即种子——保证 v2..vN 每条 ALTER 都在
// 有数据的表上执行(空表迁移暴露不了数据问题)。链跑完后:
//   1) 种子数据完整性逐表断言(含 v3 悬空 cover 预清理的正反例);
//   2) 全表非空守卫(information_schema 动态枚举)——未来 schema PR 新增表
//      不补种子即红,固化 ADR-0012「每个 schema PR」纪律;
//   3) 截断链打开新库 → SchemaDowngradeError(真 PG 版降级拒绝)。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:postgres/postgres.dart';

void main() {
  test('QG-4:v1 起边迁边种,全链数据零丢失 + 全表非空 + 降级拒绝', () async {
    final url = Platform.environment['TEST_PG_URL'];
    if (url == null || url.isEmpty) {
      markTestSkipped('TEST_PG_URL 未设置');
      return;
    }
    final conn = await Connection.openFromUrl(url);
    final schema = 'qg4_${DateTime.now().microsecondsSinceEpoch}';
    try {
      try {
        await conn.execute('CREATE EXTENSION IF NOT EXISTS pgcrypto');
      } on ServerException catch (e) {
        if (e.code != '23505') rethrow;
      }
      await conn.execute('CREATE SCHEMA "$schema"');
      await conn.execute('SET search_path TO "$schema"');

      // ── 逐版本迁移 + 版本引入表时种子 ──────────────────────────────
      // 循环上界取 kAppMigrations.length:v8 合入后自动纳入本测试。
      final seeders = <int, Future<void> Function()>{
        1: () => _seedV1(conn),
        6: () => _seedV6(conn),
        7: () => _seedV7(conn),
      };
      for (var k = 1; k <= kAppMigrations.length; k++) {
        await MigrationRunner(
          conn,
          migrations: kAppMigrations.sublist(0, k),
        ).migrate();
        await seeders[k]?.call();
      }

      // ── 1) 种子数据完整性 ─────────────────────────────────────────
      final ver = await conn
          .execute('SELECT version FROM schema_version WHERE id = 1');
      expect(ver.first[0], kAppMigrations.length);

      Future<int> count(String sql) async =>
          (await conn.execute(sql)).first[0]! as int;

      expect(await count('SELECT count(*) FROM projects'), 2);
      expect(await count('SELECT count(*) FROM canvases'), 2);
      expect(await count('SELECT count(*) FROM style_lanes'), 1);
      expect(await count('SELECT count(*) FROM nodes'), 2); // node2 已硬删
      expect(await count('SELECT count(*) FROM edges'), 2);
      expect(await count('SELECT count(*) FROM jobs'), 1);
      expect(await count('SELECT count(*) FROM batch_results'), 2);
      expect(await count('SELECT count(*) FROM characters'), 1);
      expect(await count('SELECT count(*) FROM prompt_presets'), 1);

      // v3 悬空 cover 预清理:坏引用置 NULL,好引用原样保留。
      expect(
        await count("SELECT count(*) FROM projects "
            "WHERE name = 'p-dangling' AND cover_node_id IS NULL"),
        1,
        reason: 'v3 未清理悬空 cover_node_id',
      );
      expect(
        await count("SELECT count(*) FROM projects "
            "WHERE name = 'p-main' AND cover_node_id IS NOT NULL"),
        1,
        reason: 'v3 误清有效 cover_node_id',
      );
      // JSONB 载荷原样存活(迁移不碰内容)。
      expect(
        await count("SELECT count(*) FROM nodes "
            "WHERE type_config->>'image_url' = 'canvases/c1/img.png'"),
        1,
      );
      expect(
        await count("SELECT count(*) FROM jobs "
            "WHERE parameters->>'aspect_ratio' = '16:9'"),
        1,
      );
      // 软删边仍是软删态(v3 重建唯一索引不碰行)。
      expect(
        await count('SELECT count(*) FROM edges '
            'WHERE deleted_at IS NOT NULL'),
        1,
      );
      // v3/v4 死列确已不在(迁移真的执行了,不是被跳过)。
      expect(
        await count("SELECT count(*) FROM information_schema.columns "
            "WHERE table_schema = current_schema() "
            "AND table_name = 'jobs' "
            "AND column_name IN ('retry_count','max_retries','next_poll_at')"),
        0,
      );

      // ── 2) 全表非空守卫(未来 schema PR 不补种子即红)──────────────
      final tables = await conn.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = current_schema() AND table_type = 'BASE TABLE'",
      );
      for (final row in tables) {
        final t = row[0]! as String;
        expect(
          await count('SELECT count(*) FROM "$t"'),
          greaterThan(0),
          reason: '表 $t 无种子数据——新增表必须在本测试补 seeder(QG-4 守卫)',
        );
      }

      // ── 3) 降级拒绝(真 PG 版)─────────────────────────────────────
      await expectLater(
        MigrationRunner(
          conn,
          migrations: kAppMigrations.sublist(0, kAppMigrations.length - 1),
        ).migrate,
        throwsA(isA<SchemaDowngradeError>()),
      );
    } finally {
      await conn.execute('DROP SCHEMA "$schema" CASCADE');
      await conn.close();
    }
  }, tags: const ['pg']);
}

/// v1 形态种子:覆盖 v1 全部业务表,用当时存在的列(后被删的列走默认值)。
Future<void> _seedV1(Connection conn) async {
  await conn.execute('''
    INSERT INTO projects (id, name) VALUES
      ('00000000-0000-4000-8000-000000000001', 'p-main'),
      ('00000000-0000-4000-8000-000000000002', 'p-dangling');
    INSERT INTO canvases (id, project_id, name, base_style_prefix) VALUES
      ('00000000-0000-4000-8000-0000000000c1',
       '00000000-0000-4000-8000-000000000001', 'c1', 'cinematic'),
      ('00000000-0000-4000-8000-0000000000c2',
       '00000000-0000-4000-8000-000000000002', 'c2', '');
    INSERT INTO style_lanes (id, canvas_id, label, style_prompt) VALUES
      ('00000000-0000-4000-8000-0000000000a1',
       '00000000-0000-4000-8000-0000000000c1', 'lane', 'noir');
    INSERT INTO nodes (id, canvas_id, type, node_role, status,
                       lane_id, type_config) VALUES
      ('00000000-0000-4000-8000-0000000000d1',
       '00000000-0000-4000-8000-0000000000c1', 'image', 'config', 'idle',
       '00000000-0000-4000-8000-0000000000a1',
       '{"prompt":"a cat"}'::jsonb),
      ('00000000-0000-4000-8000-0000000000d2',
       '00000000-0000-4000-8000-0000000000c1', 'image', 'result', 'success',
       NULL, '{"image_url":"canvases/c1/img.png"}'::jsonb);
    UPDATE nodes SET source_node_id = '00000000-0000-4000-8000-0000000000d1'
      WHERE id = '00000000-0000-4000-8000-0000000000d2';
    -- 有效 cover(断言 v3 保留)
    UPDATE projects SET cover_node_id = '00000000-0000-4000-8000-0000000000d2'
      WHERE id = '00000000-0000-4000-8000-000000000001';
    -- 悬空 cover 夹具:node3 设为 cover 后硬删(v1 无 FK,悬空得以存在;
    -- 断言 v3 预清理置 NULL)
    INSERT INTO nodes (id, canvas_id, type) VALUES
      ('00000000-0000-4000-8000-0000000000d3',
       '00000000-0000-4000-8000-0000000000c2', 'image');
    UPDATE projects SET cover_node_id = '00000000-0000-4000-8000-0000000000d3'
      WHERE id = '00000000-0000-4000-8000-000000000002';
    DELETE FROM nodes WHERE id = '00000000-0000-4000-8000-0000000000d3';
    -- 活边 + 软删边(不同 edge_type,满足 v1 全量 UNIQUE)
    INSERT INTO edges (canvas_id, source_node_id, target_node_id,
                       edge_type, deleted_at) VALUES
      ('00000000-0000-4000-8000-0000000000c1',
       '00000000-0000-4000-8000-0000000000d1',
       '00000000-0000-4000-8000-0000000000d2', 'data', NULL),
      ('00000000-0000-4000-8000-0000000000c1',
       '00000000-0000-4000-8000-0000000000d1',
       '00000000-0000-4000-8000-0000000000d2', 'narrative', now());
    INSERT INTO jobs (id, canvas_id, source_node_id, result_node_id,
                      provider_id, job_type, status,
                      full_prompt, user_prompt, parameters) VALUES
      ('00000000-0000-4000-8000-0000000000b1',
       '00000000-0000-4000-8000-0000000000c1',
       '00000000-0000-4000-8000-0000000000d1',
       '00000000-0000-4000-8000-0000000000d2',
       'gemini', 'image', 'success',
       'cinematic, a cat', 'a cat',
       '{"aspect_ratio":"16:9","seed":42}'::jsonb);
    INSERT INTO batch_results (node_id, job_id, slot_index, status,
                               output_url, promoted) VALUES
      ('00000000-0000-4000-8000-0000000000d2',
       '00000000-0000-4000-8000-0000000000b1', 0, 'success',
       'canvases/c1/slot0.png', true),
      ('00000000-0000-4000-8000-0000000000d2',
       '00000000-0000-4000-8000-0000000000b1', 1, 'error', NULL, false);
  ''');
}

/// v6 引入 characters。
Future<void> _seedV6(Connection conn) async {
  await conn.execute('''
    INSERT INTO characters (project_id, name, reference_image_paths) VALUES
      ('00000000-0000-4000-8000-000000000001', 'hero',
       '["characters/hero/ref1.png"]'::jsonb);
  ''');
}

/// v7 引入 prompt_presets。
Future<void> _seedV7(Connection conn) async {
  await conn.execute('''
    INSERT INTO prompt_presets (project_id, name, prompt, prefix) VALUES
      ('00000000-0000-4000-8000-000000000001', 'noir', 'moody', 'cinematic');
  ''');
}
```

实现时如遇 postgres 包 API 细节出入(如 `execute` 多语句需 simple 协议参数),对照 `test/storage/migration_runner_integration_test.dart` 与 `PgTestHarness` 的既有写法就地修正,不改测试语义。

- [ ] **Step 2: 本地起临时 PG 跑红/绿**

用仓库自带的可重定位 PG 二进制起一次性集群(brew 亦可;socket 用短路径——超 103 字符会 start 失败):

```bash
cd /Users/kerro/Projects/InkFrame
PGBIN=macos/Runner/Resources/pg/macos-arm64/bin
DATA=/tmp/qg4-pg && SOCK=/tmp/qg4-sock && rm -rf "$DATA" "$SOCK" && mkdir -p "$SOCK"
"$PGBIN/initdb" -D "$DATA" -U inkframe --auth=trust -E UTF8 >/dev/null
"$PGBIN/pg_ctl" -D "$DATA" -o "-p 59217 -k $SOCK -c listen_addresses=127.0.0.1" -w start >/dev/null
"$PGBIN/createdb" -h 127.0.0.1 -p 59217 -U inkframe inkframe_test
TEST_PG_URL="postgres://inkframe@127.0.0.1:59217/inkframe_test?sslmode=disable" \
  flutter test test/storage/schema/populated_migration_test.dart --tags pg
```

Expected: `All tests passed!`(首跑若红,按断言信息修 SQL 细节;绿后保留集群给 Task 2 复用或直接 stop)。

- [ ] **Step 3: 停临时集群 + 提交**

```bash
"$PGBIN/pg_ctl" -D "$DATA" -w stop >/dev/null && rm -rf "$DATA" "$SOCK"
git switch -c test/qg4-upgrade-drill
git add test/storage/schema/populated_migration_test.dart
git commit -m "test(storage): QG-4 CI 侧 populated-DB 迁移测试——边迁边种+全表非空守卫+降级拒绝

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 2: 真栈升级演练 E2E(@realpg)

**Files:**
- Create: `test/e2e/real_pg_upgrade_drill_e2e_test.dart`

- [ ] **Step 1: 写测试**

```dart
// QG-4 真栈升级演练:同一数据目录,「旧版应用」(截断链 v6)写数据关库 →
// 「新版应用」(全链)冷启 → 前向迁移自动执行,数据存活。
// 这是对真实用户升级路径(装新版打开旧工作区)的最忠实自动化模拟。
// 门控同 real_pg_stack_e2e_test.dart:TEST_REAL_PG=1 + INKFRAME_PG_BIN。
@Tags(['realpg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/pg_constants.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/storage/database_bootstrap.dart';
import 'package:inkframe/storage/migrations/app_migrations.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:inkframe/storage/pg_controller.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';

import '../_harness/fake_secure_storage.dart';

void main() {
  test('QG-4 真栈:旧版(v6)写入 → 关库 → 新版全链冷启 → 数据存活', () async {
    if (Platform.environment['TEST_REAL_PG'] != '1') {
      markTestSkipped('TEST_REAL_PG!=1,跳过真二进制 E2E');
      return;
    }
    final binDir = Platform.environment['INKFRAME_PG_BIN'];
    if (binDir == null || binDir.isEmpty) {
      markTestSkipped('INKFRAME_PG_BIN 未设置,跳过真二进制 E2E');
      return;
    }

    final tmp = Directory.systemTemp.createTempSync('ink_qg4_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'root')));
    await paths.ensureInitialized();
    final secure = FakeSecureStorage(); // 跨两阶段同实例:密码延续
    final locator =
        DefaultPgBinaryLocator(environment: {'INKFRAME_PG_BIN': binDir});

    Pool<void> openPool(PgRuntime rt) => Pool<void>.withEndpoints(
          [
            Endpoint(
              host: rt.host,
              port: rt.port,
              database: kPgDatabaseName,
              username: kPgSuperuser,
              password: rt.password,
            ),
          ],
          settings:
              const PoolSettings(sslMode: SslMode.disable, maxConnectionCount: 2),
        );

    // ── 阶段 1:「旧版应用」——截断链到 v6,写真数据,正常关库 ──
    const oldLen = 6;
    final oldApp =
        PgController(paths: paths, locator: locator, secureStorage: secure);
    final rt1 = await oldApp.start();
    final pool1 = openPool(rt1);
    await DatabaseBootstrap(pool1,
            migrations: kAppMigrations.sublist(0, oldLen))
        .run();
    final v1 = await pool1
        .execute('SELECT version FROM schema_version WHERE id = 1');
    expect(v1.first[0], oldLen, reason: '旧版链未停在 v$oldLen');
    final pid = await PostgresProjectRepository(pool1).create(name: 'QG4-OLD');
    await pool1.close();
    await oldApp.stop();

    // ── 阶段 2:「新版应用」——同一数据目录,全链 bootstrap 冷启 ──
    final newApp =
        PgController(paths: paths, locator: locator, secureStorage: secure);
    final rt2 = await newApp.start();
    final pool2 = openPool(rt2);
    addTearDown(() async {
      await pool2.close();
      await newApp.stop();
    });
    await DatabaseBootstrap(pool2).run(); // 生产同路径:kAppMigrations 全链

    final v2 = await pool2
        .execute('SELECT version FROM schema_version WHERE id = 1');
    expect(v2.first[0], kAppMigrations.length, reason: '前向迁移未到最新版');
    // 旧版数据存活。
    final survived = await PostgresProjectRepository(pool2).findById(pid);
    expect(survived, isNotNull, reason: '升级后旧数据丢失');
    expect(survived!.name, 'QG4-OLD');
    // 新版新增表可用(v7 prompt_presets)。
    final presets = await pool2
        .execute('SELECT count(*) FROM prompt_presets');
    expect(presets.first[0], 0);
  }, tags: const ['realpg'], timeout: const Timeout(Duration(minutes: 3)));
}
```

实现时对照 `test/e2e/real_pg_stack_e2e_test.dart` 校正:`PgRuntime` 类型名、`kPgDatabaseName`/`kPgSuperuser` 实际所在文件(该 E2E 里从哪个 import 来就用哪个)、`PostgresProjectRepository.create` 返回值形态。语义不变。

- [ ] **Step 2: 本地真二进制跑通**

```bash
TEST_REAL_PG=1 INKFRAME_PG_BIN="$PWD/macos/Runner/Resources/pg/macos-arm64/bin" \
  flutter test test/e2e/real_pg_upgrade_drill_e2e_test.dart --tags realpg
```

Expected: `All tests passed!`(约 10-20s:两轮 initdb-free 的 start/stop + 迁移)。

- [ ] **Step 3: 提交**

```bash
git add test/e2e/real_pg_upgrade_drill_e2e_test.dart
git commit -m "test(e2e): QG-4 真栈升级演练——旧版(v6)数据目录被新版全链冷启前向迁移,数据存活

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 3: 人工侧 SOP + 文档回填

**Files:**
- Modify: `docs/BUILD-RELEASE.md`(追加「升级演练(QG-4)」一节;若该文件无合适挂点则挂 `docs/EXECUTION-PLAYBOOK.md`,二选一,不重复)
- Modify: `docs/BOARD.md`(近期落地表加行)
- Modify: `docs/MASTERPLAN.md:248`(beta.1 硬阻塞名单剔除 QG-4)
- Modify: `docs/superpowers/plans/2026-07-07-launch-release-engineering.md`(QG-4 卡加状态行)

- [ ] **Step 1: SOP 一节(BUILD-RELEASE.md 末尾追加)**

```markdown
## 升级演练(QG-4)

每次发版前跑两层,全绿才发:

1. **自动层(必跑)**:
   - CI 侧随 PR 自动跑(`populated_migration_test.dart`,@pg);
   - 真栈演练本机一键:
     `TEST_REAL_PG=1 INKFRAME_PG_BIN="$PWD/macos/Runner/Resources/pg/macos-arm64/bin" flutter test --tags realpg`
     (含全栈 E2E 与升级演练两条;Windows 机把 INKFRAME_PG_BIN 指向
     `windows/runner/resources/pg/windows-x64/bin`)。
2. **人工层(建议每个 minor 一次)**:真实安装物 + 真实旧工作区快照。
   - 备夹具:从装过旧版的机器拷贝整个数据根
     (mac `~/Library/Application Support/InkFrame`,win `%LOCALAPPDATA%\InkFrame`)
     存为 `snapshot-<旧版本号>/`;
   - 演练:复制快照到临时 HOME,再用**新版安装物**启动——
     mac:`cp -R snapshot-vX ~/qg4-home/Library/Application\ Support/InkFrame && HOME=~/qg4-home open -W <新版>.app`;
   - 通过标准:应用正常进入 Studio、旧项目可打开、无数据重置/报错;
     结束后删临时 HOME。快照本身永不改动(只用副本)。

新增 schema 版本时:`populated_migration_test.dart` 的全表非空守卫会强制你
为新表补 seeder——这是有意设计,勿绕过(ADR-0012「每个 schema PR」纪律)。
```

- [ ] **Step 2: 三处状态回填**

MASTERPLAN :248 「beta.1 被 U1+U2+QG-4 升级演练硬阻塞」改为「beta.1 被 U1+U2 硬阻塞(QG-4 已随 #205 落地:CI populated 迁移测 + realpg 升级演练 + SOP)」;launch 明细 QG-4 卡(:146-148)追加:

```markdown
- 状态:已随 #205 落地——CI 侧 `populated_migration_test.dart`(@pg,边迁边种+全表非空守卫+
  降级拒绝);真栈侧 `real_pg_upgrade_drill_e2e_test.dart`(@realpg,v6 数据目录被全链冷启前向
  迁移);人工侧 SOP 见 BUILD-RELEASE「升级演练」。**QG-4 ✅,beta.1 阻塞只剩 U1/U2**。
```

BOARD 近期落地表(#204 行后)追加:

```markdown
| QG-4 数据升级演练:CI populated-DB 迁移测(v1 起边迁边种+information_schema 全表非空守卫钉死「每个 schema PR 补种子」+真 PG 降级拒绝)+ realpg 升级演练 E2E(旧版 v6 数据目录→新版全链冷启数据存活)+ 发版 SOP 入 BUILD-RELEASE——beta.1 硬阻塞三件套清剩 U1/U2 | #205 |
```

(PR 号预写 #205,建 PR 时核实,不符则全局替换。)

- [ ] **Step 3: 全量闸门 + 提交**

```bash
flutter analyze lib test && flutter test --exclude-tags golden
git add docs/BUILD-RELEASE.md docs/BOARD.md docs/MASTERPLAN.md \
        docs/superpowers/plans/2026-07-07-launch-release-engineering.md \
        docs/superpowers/plans/2026-07-28-qg-4-upgrade-drill.md
git commit -m "docs: QG-4 SOP 入 BUILD-RELEASE + 三处状态回填——beta.1 阻塞清剩 U1/U2

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Expected: analyze 干净;全测试过(新增两文件:pg/realpg 标签在无环境变量时自跳过,不拖慢默认跑)。

### Task 4: PR + CI + 合并

- [ ] **Step 1: push(pbcopy 后用户 `!` 执行)+ 建 PR**

```bash
git push -u origin test/qg4-upgrade-drill
gh pr create --title "test: QG-4 数据升级演练——CI populated 迁移测 + realpg 升级演练 + SOP" \
  --body "(要点同三条 commit;强调:CI job 的 postgres:17 service 会真跑 populated 测试;realpg 条 CI 无二进制自跳过,本机验证证据见 PR 描述附执行输出)"
```

- [ ] **Step 2: 核实 CI 的 test job 里 populated 测试真的跑了(非 skip)**

```bash
gh pr checks <PR#> --watch
gh run view <run-id> --log 2>/dev/null | grep -i "populated\|QG-4" | head
```

Expected: 日志中出现 QG-4 用例名且无 `markTestSkipped`。**这一步不可省**——@pg 测试静默 skip 也是绿,必须看日志确认真执行(温室数据陷阱)。

- [ ] **Step 3: 合并 + 核对 PR 号回填**

```bash
gh pr merge <PR#> --squash --delete-branch
```

若实际 PR 号 ≠ #205,合并前先在分支上把三处文档的 #205 全局替换为实际号再 push。
