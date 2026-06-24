# Backend P0#2 — Repository Boundary Typing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kill the "thin abstraction" root cause at the repository boundary — converge every scattered `as String` / `!.toString()` / per-model `_asDouble` row cast into one typed decoder that throws a *typed* `LocalIOError` (not a raw `_TypeError`/`FormatException`), and replace every stringly-typed column name with a compile-checked constant.

**Architecture:** Keep the `Map<String, Object?>` repo edge (ADR-0003 — do **not** introduce freezed domain rows). Add two pure-Dart artifacts in `lib/core/db/`: (1) `DbRow` extension on `Map<String, Object?>` with safe typed accessors; (2) per-table column-name constants. Every `fromRow` and every direct repo-row read migrates to `row.reqString(NodeCol.type)`-style calls. A pg-tagged guard test validates the constant *values* against the live DB schema, so a wrong column string fails CI, not production.

**Tech Stack:** Dart, Flutter, `postgres` v3, flutter_test. No codegen for these (hand-written, mirroring the project's hand-rolled-model convention).

## Global Constraints

- DI only via Riverpod; depend on abstractions (docs/CLAUDE.md §SOLID-D). No new singletons.
- Zero backward compatibility: replace casts outright; do not keep the old `_asDouble`/`as` paths "just in case".
- Errors are `InkError` subtypes only. Decode failures throw `LocalIOError(extra: {op:'decode', column, expected, actual})`. `enum`-parse failures keep their existing `FormatException` (schema CHECK already guards these; out of scope to change).
- Comments in Chinese, minimal.
- Every commit compiles, passes `C:\Users\Kerro\flutter\bin\flutter.bat analyze` (0 issues) and `flutter.bat test --exclude-tags pg`, keeps en/zh ARB parity (no ARB changes here).
- Flutter is not on PATH: invoke `C:\Users\Kerro\flutter\bin\flutter.bat`.
- pg-tagged tests (`@Tags(['pg'])`) skip without `TEST_PG_URL`; CI (postgres:17) runs them. Reuse `test/storage/schema/pg_test_harness.dart` (`PgTestHarness.openFromEnv(Platform.environment, '<label>')`, `.conn`, `.close()`).
- **Layering:** both new files live in `lib/core/db/` (core = shared abstraction). Repos (`lib/storage`) and feature models (`lib/features`) both import *down* into core — never the reverse. Do **not** put column constants in `lib/storage` (would force feature models to depend on storage).
- **Schema reality:** current schema is **v4**. `jobs.next_poll_at` was **dropped in v4** (`004_drop_next_poll.sql`) — it must NOT appear in `JobCol`.

---

### Task 1: `DbRow` typed row accessors

**Files:**
- Create: `lib/core/db/row_reader.dart`
- Test: `test/core/db/row_reader_test.dart`

**Interfaces:**
- Produces (extension `DbRow on Map<String, Object?>`):
  - `String reqString(String col)` — non-null TEXT; null/non-String → `LocalIOError`.
  - `String? optString(String col)` — null → null; non-String → `LocalIOError`.
  - `String reqId(String col)` — UUID; null → `LocalIOError`; else `.toString()` (driver may return `String` or `UuidValue`).
  - `String? optId(String col)` — null → null; else `.toString()`.
  - `int reqInt(String col)` / `int? optInt(String col)` — INTEGER/BIGINT.
  - `double? optDouble(String col)` — null → null; `num` → `toDouble()`; else `LocalIOError`.
  - `bool? optBool(String col)` — null → null; non-bool → `LocalIOError`.

- [ ] **Step 1: Write the failing test** `test/core/db/row_reader_test.dart`:

```dart
// DbRow 类型化访问器单测：类型不符抛 LocalIOError(op:'decode')，取代裸 _TypeError。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/db/row_reader.dart';
import 'package:inkframe/core/errors/ink_error.dart';

void main() {
  group('DbRow', () {
    final row = <String, Object?>{
      's': 'hi',
      'n': null,
      'i': 7,
      'd': 1.5,
      'di': 2, // num 但非 double
      'b': true,
      'id': 'uuid-text',
    };

    test('reqString 返回值；缺失/类型错 → LocalIOError', () {
      expect(row.reqString('s'), 'hi');
      expect(() => row.reqString('n'), throwsA(isA<LocalIOError>()));
      expect(() => row.reqString('i'), throwsA(isA<LocalIOError>()));
    });

    test('optString: null→null；类型错→LocalIOError', () {
      expect(row.optString('n'), isNull);
      expect(row.optString('s'), 'hi');
      expect(() => row.optString('i'), throwsA(isA<LocalIOError>()));
    });

    test('reqId 字符串化；null→LocalIOError', () {
      expect(row.reqId('id'), 'uuid-text');
      expect(row.reqId('i'), '7');
      expect(() => row.reqId('n'), throwsA(isA<LocalIOError>()));
    });

    test('optId: null→null；否则字符串化', () {
      expect(row.optId('n'), isNull);
      expect(row.optId('i'), '7');
    });

    test('optInt / reqInt', () {
      expect(row.optInt('i'), 7);
      expect(row.optInt('n'), isNull);
      expect(row.reqInt('i'), 7);
      expect(() => row.reqInt('s'), throwsA(isA<LocalIOError>()));
    });

    test('optDouble: num→toDouble；null→null；非num→LocalIOError', () {
      expect(row.optDouble('d'), 1.5);
      expect(row.optDouble('di'), 2.0);
      expect(row.optDouble('n'), isNull);
      expect(() => row.optDouble('s'), throwsA(isA<LocalIOError>()));
    });

    test('optBool', () {
      expect(row.optBool('b'), true);
      expect(row.optBool('n'), isNull);
      expect(() => row.optBool('i'), throwsA(isA<LocalIOError>()));
    });

    test('LocalIOError.extra 带 op/column/expected/actual', () {
      try {
        row.reqString('i');
        fail('should throw');
      } on LocalIOError catch (e) {
        expect(e.extra?['op'], 'decode');
        expect(e.extra?['column'], 'i');
        expect(e.extra?['expected'], 'String');
        expect(e.extra?['actual'], 'int');
      }
    });
  });
}
```

- [ ] **Step 2: Run the test, watch it fail**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/core/db/row_reader_test.dart`
Expected: FAIL — `row_reader.dart` does not exist (URI doesn't resolve).

- [ ] **Step 3: Write the implementation** `lib/core/db/row_reader.dart`:

```dart
// 类型化行解码：把仓储 Map<String,Object?> 边界的强转收敛到一处。
// 类型不符抛 LocalIOError(op:'decode')，取代散落的 `as` 崩溃(_TypeError)与各自的 _asDouble。
// ADR-0003 不废弃 Map 边界——本扩展只让 fromRow / 行读取变安全可诊断。
import '../errors/ink_error.dart';

extension DbRow on Map<String, Object?> {
  LocalIOError _decodeError(String col, String expected, Object? actual) =>
      LocalIOError(
        extra: <String, Object?>{
          'op': 'decode',
          'column': col,
          'expected': expected,
          'actual': actual?.runtimeType.toString() ?? 'null',
        },
      );

  /// 必填文本列(TEXT)。null 或非 String → LocalIOError。
  String reqString(String col) {
    final v = this[col];
    if (v is String) return v;
    throw _decodeError(col, 'String', v);
  }

  /// 可空文本列。null → null；非 String → LocalIOError。
  String? optString(String col) {
    final v = this[col];
    if (v == null) return null;
    if (v is String) return v;
    throw _decodeError(col, 'String', v);
  }

  /// 必填 id 列(UUID)。null → LocalIOError；否则字符串化(驱动可能回 String 或 UuidValue)。
  String reqId(String col) {
    final v = this[col];
    if (v == null) throw _decodeError(col, 'id', v);
    return v.toString();
  }

  /// 可空 id 列。null → null；否则字符串化。
  String? optId(String col) => this[col]?.toString();

  /// 必填整数列(INTEGER/BIGINT)。
  int reqInt(String col) {
    final v = this[col];
    if (v is int) return v;
    throw _decodeError(col, 'int', v);
  }

  /// 可空整数列。null → null；非 int → LocalIOError。
  int? optInt(String col) {
    final v = this[col];
    if (v == null) return null;
    if (v is int) return v;
    throw _decodeError(col, 'int', v);
  }

  /// 可空浮点列(REAL/double precision)。null → null；num → toDouble；否则 LocalIOError。
  double? optDouble(String col) {
    final v = this[col];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    throw _decodeError(col, 'double', v);
  }

  /// 可空布尔列(BOOLEAN)。null → null；非 bool → LocalIOError。
  bool? optBool(String col) {
    final v = this[col];
    if (v == null) return null;
    if (v is bool) return v;
    throw _decodeError(col, 'bool', v);
  }
}
```

- [ ] **Step 4: Run the test, watch it pass**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/core/db/row_reader_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/db/row_reader.dart test/core/db/row_reader_test.dart
git commit -m "feat(core): DbRow typed row accessors → typed LocalIOError on decode mismatch"
```

---

### Task 2: Per-table column-name constants + pg schema guard

**Files:**
- Create: `lib/core/db/columns.dart`
- Test: `test/core/db/columns_schema_test.dart` (pg-tagged)

**Interfaces:**
- Produces: `NodeCol`, `EdgeCol`, `JobCol`, `CanvasCol`, `ProjectCol`, `StyleLaneCol`, `BatchResultCol`, `SchemaVersionCol` — each an abstract-final class of `static const String` fields whose *values* are the real snake_case column names. `NodeCol.projectId` is the JOIN-derived `'project_id'` read in node `fromRow`.

- [ ] **Step 1: Write the constants** `lib/core/db/columns.dart` (values verbatim from `schema_v1.dart`; `jobs.next_poll_at` omitted — dropped in v4):

```dart
// 列名常量：消灭仓储/模型里散落的字符串列名 typo。
// 值 = 真实 snake_case 列名(真相源 lib/storage/schema/schema_v1.dart，jobs.next_poll_at 于 v4 删除)。
// columns_schema_test.dart(pg) 把这些值对真库 information_schema 校验，写错即 CI 红。

abstract final class ProjectCol {
  static const id = 'id';
  static const name = 'name';
  static const coverNodeId = 'cover_node_id';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
}

abstract final class CanvasCol {
  static const id = 'id';
  static const projectId = 'project_id';
  static const name = 'name';
  static const baseStylePrefix = 'base_style_prefix';
  static const baseStyleSuffix = 'base_style_suffix';
  static const viewportX = 'viewport_x';
  static const viewportY = 'viewport_y';
  static const viewportScale = 'viewport_scale';
  static const defaultNodeWidth = 'default_node_width';
  static const laneDirection = 'lane_direction';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
}

abstract final class StyleLaneCol {
  static const id = 'id';
  static const canvasId = 'canvas_id';
  static const label = 'label';
  static const stylePrompt = 'style_prompt';
  static const sortOrder = 'sort_order';
  static const tintColor = 'tint_color';
  static const size = 'size';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
}

abstract final class NodeCol {
  static const id = 'id';
  static const canvasId = 'canvas_id';
  static const type = 'type';
  static const label = 'label';
  static const nodeRole = 'node_role';
  static const status = 'status';
  static const sourceNodeId = 'source_node_id';
  static const positionX = 'position_x';
  static const positionY = 'position_y';
  static const width = 'width';
  static const height = 'height';
  static const zIndex = 'z_index';
  static const laneId = 'lane_id';
  static const typeConfig = 'type_config';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';

  /// 读路径 JOIN canvases 带出，非 nodes 表自身列；schema guard 不校验此列。
  static const projectId = 'project_id';
}

abstract final class EdgeCol {
  static const id = 'id';
  static const canvasId = 'canvas_id';
  static const sourceNodeId = 'source_node_id';
  static const targetNodeId = 'target_node_id';
  static const edgeType = 'edge_type';
  static const role = 'role';
  static const sortOrder = 'sort_order';
  static const createdAt = 'created_at';
  static const deletedAt = 'deleted_at';
}

abstract final class JobCol {
  static const id = 'id';
  static const canvasId = 'canvas_id';
  static const sourceNodeId = 'source_node_id';
  static const resultNodeId = 'result_node_id';
  static const providerId = 'provider_id';
  static const jobType = 'job_type';
  static const status = 'status';
  static const remoteTaskId = 'remote_task_id';
  static const fullPrompt = 'full_prompt';
  static const userPrompt = 'user_prompt';
  static const parameters = 'parameters';
  static const batchSize = 'batch_size';
  static const progress = 'progress';
  static const errorCode = 'error_code';
  static const errorMessage = 'error_message';
  static const retryCount = 'retry_count';
  static const maxRetries = 'max_retries';
  static const timeoutAt = 'timeout_at';
  static const createdAt = 'created_at';
  static const submittedAt = 'submitted_at';
  static const completedAt = 'completed_at';
}

abstract final class BatchResultCol {
  static const id = 'id';
  static const nodeId = 'node_id';
  static const jobId = 'job_id';
  static const slotIndex = 'slot_index';
  static const status = 'status';
  static const outputUrl = 'output_url';
  static const thumbnailUrl = 'thumbnail_url';
  static const width = 'width';
  static const height = 'height';
  static const fileSizeBytes = 'file_size_bytes';
  static const seed = 'seed';
  static const errorCode = 'error_code';
  static const errorMessage = 'error_message';
  static const promoted = 'promoted';
  static const promotedNodeId = 'promoted_node_id';
  static const createdAt = 'created_at';
  static const completedAt = 'completed_at';
}

abstract final class SchemaVersionCol {
  static const id = 'id';
  static const version = 'version';
  static const appliedAt = 'applied_at';
}
```

- [ ] **Step 2: Write the pg guard test** `test/core/db/columns_schema_test.dart` (validates the string *values* against the real DB — catches a wrong column name that the Dart compiler can't):

```dart
// 列名常量对真库 information_schema 校验：常量值必须是表的真实列。pg-tagged。
@Tags(['pg'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/db/columns.dart';
import 'package:postgres/postgres.dart';

import '../../storage/schema/pg_test_harness.dart';

void main() {
  // 每个表 → 该表必须存在的列常量集合(NodeCol.projectId 是 JOIN 列，排除)。
  final expected = <String, List<String>>{
    'projects': [ProjectCol.id, ProjectCol.name, ProjectCol.coverNodeId, ProjectCol.createdAt, ProjectCol.updatedAt, ProjectCol.deletedAt],
    'canvases': [CanvasCol.id, CanvasCol.projectId, CanvasCol.name, CanvasCol.baseStylePrefix, CanvasCol.baseStyleSuffix, CanvasCol.viewportX, CanvasCol.viewportY, CanvasCol.viewportScale, CanvasCol.defaultNodeWidth, CanvasCol.laneDirection, CanvasCol.createdAt, CanvasCol.updatedAt, CanvasCol.deletedAt],
    'style_lanes': [StyleLaneCol.id, StyleLaneCol.canvasId, StyleLaneCol.label, StyleLaneCol.stylePrompt, StyleLaneCol.sortOrder, StyleLaneCol.tintColor, StyleLaneCol.size, StyleLaneCol.createdAt, StyleLaneCol.updatedAt, StyleLaneCol.deletedAt],
    'nodes': [NodeCol.id, NodeCol.canvasId, NodeCol.type, NodeCol.label, NodeCol.nodeRole, NodeCol.status, NodeCol.sourceNodeId, NodeCol.positionX, NodeCol.positionY, NodeCol.width, NodeCol.height, NodeCol.zIndex, NodeCol.laneId, NodeCol.typeConfig, NodeCol.createdAt, NodeCol.updatedAt, NodeCol.deletedAt],
    'edges': [EdgeCol.id, EdgeCol.canvasId, EdgeCol.sourceNodeId, EdgeCol.targetNodeId, EdgeCol.edgeType, EdgeCol.role, EdgeCol.sortOrder, EdgeCol.createdAt, EdgeCol.deletedAt],
    'jobs': [JobCol.id, JobCol.canvasId, JobCol.sourceNodeId, JobCol.resultNodeId, JobCol.providerId, JobCol.jobType, JobCol.status, JobCol.remoteTaskId, JobCol.fullPrompt, JobCol.userPrompt, JobCol.parameters, JobCol.batchSize, JobCol.progress, JobCol.errorCode, JobCol.errorMessage, JobCol.retryCount, JobCol.maxRetries, JobCol.timeoutAt, JobCol.createdAt, JobCol.submittedAt, JobCol.completedAt],
    'batch_results': [BatchResultCol.id, BatchResultCol.nodeId, BatchResultCol.jobId, BatchResultCol.slotIndex, BatchResultCol.status, BatchResultCol.outputUrl, BatchResultCol.thumbnailUrl, BatchResultCol.width, BatchResultCol.height, BatchResultCol.fileSizeBytes, BatchResultCol.seed, BatchResultCol.errorCode, BatchResultCol.errorMessage, BatchResultCol.promoted, BatchResultCol.promotedNodeId, BatchResultCol.createdAt, BatchResultCol.completedAt],
    'schema_version': [SchemaVersionCol.id, SchemaVersionCol.version, SchemaVersionCol.appliedAt],
  };

  late PgTestHarness? harness;
  setUp(() async {
    harness = await PgTestHarness.openFromEnv(Platform.environment, 'cols');
  });
  tearDown(() async => harness?.close());

  test('每个表的列常量都存在于真库 information_schema', () async {
    final h = harness;
    if (h == null) {
      markTestSkipped('TEST_PG_URL 未设置，跳过');
      return;
    }
    for (final entry in expected.entries) {
      final r = await h.conn.execute(
        Sql.named(
          'SELECT column_name FROM information_schema.columns WHERE table_name = @t',
        ),
        parameters: <String, Object?>{'t': entry.key},
      );
      final actual = r.map((row) => row[0]! as String).toSet();
      for (final col in entry.value) {
        expect(actual, contains(col),
            reason: '${entry.key} 缺列常量 "$col"（schema 漂移或常量写错）');
      }
    }
  });
}
```

- [ ] **Step 3: Analyze + run (skips locally without TEST_PG_URL)**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat analyze lib/core/db/columns.dart test/core/db/columns_schema_test.dart`
Then: `C:\Users\Kerro\flutter\bin\flutter.bat test test/core/db/columns_schema_test.dart`
Expected: analyze clean; test PASS-or-skipped locally (real assertions run in CI with PG).

- [ ] **Step 4: Commit**

```bash
git add lib/core/db/columns.dart test/core/db/columns_schema_test.dart
git commit -m "feat(core): per-table column-name constants + pg schema-drift guard test"
```

---

### Task 3: Migrate `CanvasNode.fromRow` (worked exemplar)

**Files:**
- Modify: `lib/features/canvas/models/canvas_node.dart`
- Test: `test/features/canvas/models/canvas_node_test.dart` (extend if exists; else create)

**Interfaces:**
- Consumes: `DbRow` (Task 1), `NodeCol` (Task 2). No signature change to `CanvasNode.fromRow` (still `Map → CanvasNode`).

- [ ] **Step 1: Add/extend the test** — assert a malformed row now throws `LocalIOError`, not `_TypeError`. Append to (or create) `test/features/canvas/models/canvas_node_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  group('CanvasNode.fromRow typing', () {
    Map<String, Object?> base() => <String, Object?>{
          'id': 'n1',
          'type': 'image',
          'node_role': 'config',
          'label': 'A',
          'canvas_id': 'c1',
          'position_x': 10.0,
          'position_y': 20.0,
          'width': 240.0,
          'height': 240.0,
          'type_config': <String, Object?>{},
        };

    test('happy path', () {
      final n = CanvasNodeMapping.fromRow(base());
      expect(n.id, 'n1');
      expect(n.type, CanvasNodeType.image);
      expect(n.role, NodeRole.config);
      expect(n.label, 'A');
      expect(n.position.dx, 10.0);
    });

    test('type 列类型错(非 String) → LocalIOError', () {
      final row = base()..['type'] = 123;
      expect(() => CanvasNodeMapping.fromRow(row),
          throwsA(isA<LocalIOError>()));
    });

    test('width 列类型错(非 num) → LocalIOError', () {
      final row = base()..['width'] = 'wide';
      expect(() => CanvasNodeMapping.fromRow(row),
          throwsA(isA<LocalIOError>()));
    });
  });
}
```

- [ ] **Step 2: Run, watch fail**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/features/canvas/models/canvas_node_test.dart`
Expected: FAIL — current `fromRow` throws `_TypeError` (cast), not `LocalIOError`.

- [ ] **Step 3: Rewrite** the `CanvasNodeMapping` extension and delete the now-unused top-level `_asDouble`. Add imports at top of `canvas_node.dart`:

```dart
import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
```

Replace the `CanvasNodeMapping` extension body with:

```dart
extension CanvasNodeMapping on CanvasNode {
  /// 从 NodeRepository 返回的单行 Map 构造 UI 模型。
  /// 列类型不符 → LocalIOError(op:'decode')；type/role 非法 → FormatException(schema CHECK 已先保护)。
  static CanvasNode fromRow(Map<String, Object?> row) {
    final typeStr = row.reqString(NodeCol.type);
    final roleStr = row.reqString(NodeCol.nodeRole);
    return CanvasNode(
      id: row.reqId(NodeCol.id),
      label: row.optString(NodeCol.label) ?? '',
      type: CanvasNodeType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => throw FormatException('Unknown node type: $typeStr'),
      ),
      role: NodeRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => throw FormatException('Unknown node role: $roleStr'),
      ),
      projectId: row.optString(NodeCol.projectId),
      canvasId: row.optId(NodeCol.canvasId),
      sourceNodeId: row.optId(NodeCol.sourceNodeId),
      laneId: row.optId(NodeCol.laneId),
      typeConfig: _parseTypeConfig(row[NodeCol.typeConfig]),
      position: Offset(
        row.optDouble(NodeCol.positionX) ?? 0,
        row.optDouble(NodeCol.positionY) ?? 0,
      ),
      size: Size(
        row.optDouble(NodeCol.width) ?? 240,
        row.optDouble(NodeCol.height) ?? 240,
      ),
    );
  }
}
```

Then **delete** the top-level `double? _asDouble(Object? v) { ... }` function at the bottom of the file (replaced by `DbRow.optDouble`). Keep `_parseTypeConfig` unchanged (JSONB needs its String/Map/null normalization).

- [ ] **Step 4: Run, watch pass + no regressions in the file's existing tests**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/features/canvas/models/canvas_node_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/canvas/models/canvas_node.dart test/features/canvas/models/canvas_node_test.dart
git commit -m "refactor(canvas): CanvasNode.fromRow via DbRow + NodeCol; drop per-model _asDouble"
```

---

### Task 4: Migrate `CanvasEdge.fromRow`

**Files:**
- Modify: `lib/features/canvas/models/canvas_edge.dart`
- Test: `test/features/canvas/models/canvas_edge_test.dart` (extend if exists; else create)

**Interfaces:**
- Consumes: `DbRow`, `EdgeCol`. No signature change.

- [ ] **Step 1: Add the typed-failure test** to `test/features/canvas/models/canvas_edge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';

void main() {
  Map<String, Object?> base() => <String, Object?>{
        'id': 'e1',
        'canvas_id': 'c1',
        'source_node_id': 'a',
        'target_node_id': 'b',
        'edge_type': 'data',
        'role': 'reference',
        'sort_order': 0,
      };

  test('happy path', () {
    final e = CanvasEdgeMapping.fromRow(base());
    expect(e.id, 'e1');
    expect(e.edgeType, EdgeType.data);
    expect(e.role, EdgeRole.reference);
  });

  test('edge_type 列类型错 → LocalIOError', () {
    final row = base()..['edge_type'] = 9;
    expect(() => CanvasEdgeMapping.fromRow(row), throwsA(isA<LocalIOError>()));
  });
}
```

- [ ] **Step 2: Run, watch fail**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/features/canvas/models/canvas_edge_test.dart`
Expected: FAIL — current cast throws `_TypeError`.

- [ ] **Step 3: Rewrite** the `fromRow` inside `CanvasEdgeMapping`. Add imports at top of `canvas_edge.dart`:

```dart
import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
```

Replace the `static CanvasEdge fromRow(...)` body (keep `_parseType` / `_parseRole` / `typeToDb` / `roleToDb` unchanged):

```dart
  static CanvasEdge fromRow(Map<String, Object?> row) {
    final typeStr = row.reqString(EdgeCol.edgeType);
    final roleStr = row.optString(EdgeCol.role) ?? 'reference';
    return CanvasEdge(
      id: row.reqId(EdgeCol.id),
      canvasId: row.reqId(EdgeCol.canvasId),
      sourceNodeId: row.reqId(EdgeCol.sourceNodeId),
      targetNodeId: row.reqId(EdgeCol.targetNodeId),
      edgeType: _parseType(typeStr),
      role: _parseRole(roleStr),
      sortOrder: row.optInt(EdgeCol.sortOrder) ?? 0,
    );
  }
```

- [ ] **Step 4: Run, watch pass**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test test/features/canvas/models/canvas_edge_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/canvas/models/canvas_edge.dart test/features/canvas/models/canvas_edge_test.dart
git commit -m "refactor(canvas): CanvasEdge.fromRow via DbRow + EdgeCol"
```

---

### Task 5: Migrate remaining model `fromRow` sites

> Mechanical application of the **Task 3 pattern** (`as`/`!.toString()` → `DbRow` accessors; string column → `*Col` constant) to every other model that maps a repo row. The transform rule is fixed; the only variable is which columns each model reads — and those column constants are fully defined in Task 2. **For each file: read it first, apply the rule, add a typed-failure test mirroring Task 3 Step 1, run that file's test, commit.**

**Accessor mapping rule (apply uniformly):**
- `row['c'] as String` → `row.reqString(XCol.c)`
- `(row['c'] as String?) ?? d` → `row.optString(XCol.c) ?? d`
- `row['c']!.toString()` (UUID/id) → `row.reqId(XCol.c)`
- `row['c']?.toString()` (UUID/id) → `row.optId(XCol.c)`
- `(row['c'] as int?) ?? d` → `row.optInt(XCol.c) ?? d`
- `_asDouble(row['c']) ?? d` / `row['c'] as double` → `row.optDouble(XCol.c) ?? d`
- `row['c'] as bool` / `== true` → `row.optBool(XCol.c) ?? false`
- JSONB columns (`type_config`, `parameters`) → keep the existing String/Map normalization helper, but key it with the constant: `_parse(row[XCol.parameters])`.

**Files to migrate (each: read → transform → test → commit):**

- [ ] **Step 1 — `lib/features/canvas/models/style_lane.dart`** (`StyleLaneCol`): columns `id, canvas_id, label, style_prompt, sort_order, tint_color, size`. Add the two `../../../core/db/*` imports. Add a `LocalIOError`-on-mismatch test → `test/features/canvas/models/style_lane_test.dart`. Commit `refactor(canvas): StyleLane.fromRow via DbRow + StyleLaneCol`.

- [ ] **Step 2 — Job-row mapping** (`JobCol`). Find the job-row reader: `grep -rn "as String\|!.toString()\|as int\|_asDouble" lib/services/job_queue_service.dart lib/features/generation/`. Migrate the job-row decode (columns `id, canvas_id, source_node_id, result_node_id, provider_id, job_type, status, remote_task_id, full_prompt, user_prompt, parameters, batch_size, progress, error_code, error_message, retry_count, max_retries, timeout_at, created_at, submitted_at, completed_at`). Add a typed-failure test in the nearest existing test file for that reader. Commit `refactor(generation): job-row decode via DbRow + JobCol`.

- [ ] **Step 3 — `batch_results` mapping** (`BatchResultCol`), if a reader exists (`grep -rn "batch_results\|slot_index\|output_url" lib/`). Migrate; test; commit `refactor(storage): batch_result-row decode via DbRow + BatchResultCol`.

- [ ] **Step 4 — Canvas / Project row reads** (`CanvasCol` / `ProjectCol`). Find consumers of `canvasRepository`/`projectRepository` `findById`/`listAll` Maps: `grep -rn "base_style_prefix\|viewport_\|lane_direction\|'name'\]\|project_id" lib/features lib/services`. Migrate each direct read (notably `lib/features/canvas/providers/canvas_base_style.dart` reads `base_style_prefix`/`base_style_suffix`; `lib/features/canvas/providers/canvas_lanes_controller.dart`). Test + commit per file: `refactor(<area>): <thing>-row decode via DbRow + <Col>`.

- [ ] **Step 5 — Sweep for stragglers**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test --exclude-tags pg`
Then: `grep -rnE "row\['|\] as String|!\.toString\(\)" lib/storage lib/features lib/services | grep -v "\.freezed\.dart"`
Expected: remaining hits are NOT repo-row decodes (e.g. provider *response* JSON parsing — that is **P1-4**, out of scope here; node `typeConfig` key reads inside widgets — out of scope, frontend-redo territory). Note any genuinely-missed repo-row decode and migrate it before proceeding.

> **Scope guard:** Do NOT touch provider response-body parsing (`(x as Map)['k']` in `lib/providers/*`) — that is a separate item (P1-4 `providerInvalidResponse`). P0#2 is strictly the **DB-row** boundary.

---

### Task 6: Adopt column constants at silent-typo write surfaces

> The genuinely *silent* typo path is patch-map **keys** (a mistyped key silently updates the wrong/no column). Static SQL templates fail loudly (PgException → `LocalIOError`), so they are optional. Convert patch-map keys passed to `update()` / `buildUpdate()` to `*Col` constants.

**Files:** the repos + controllers that build patch maps. Find them:

- [ ] **Step 1:** `grep -rnE "update\(.*\{|patchTypeConfig|softDeletePatch|restorePatch|'sort_order'|'base_style_|'deleted_at'|'updated_at'" lib/storage lib/features | grep -v "\.freezed\.dart"`

- [ ] **Step 2:** For each patch literal, replace the string key with the constant, e.g.:
  - `{'sort_order': i}` → `{StyleLaneCol.sortOrder: i}`
  - `{'base_style_prefix': p, 'base_style_suffix': s}` → `{CanvasCol.baseStylePrefix: p, CanvasCol.baseStyleSuffix: s}`
  - In `base_repository.dart` `softDeletePatch`/`restorePatch`/`withUpdatedAt`: `'deleted_at'`/`'updated_at'` → introduce a shared `CommonCol { static const updatedAt = 'updated_at'; static const deletedAt = 'deleted_at'; }` in `columns.dart` (or reuse `NodeCol.updatedAt`-style — prefer a dedicated `CommonCol` since these are cross-table). Keep `BaseRepository` importing `../core/db/columns.dart`.

- [ ] **Step 3:** Run the affected tests + analyze.

Run: `C:\Users\Kerro\flutter\bin\flutter.bat analyze` then `C:\Users\Kerro\flutter\bin\flutter.bat test --exclude-tags pg`
Expected: 0 issues; all pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(storage): patch-map keys via column constants (kill silent column typos)"
```

> If `CommonCol` was added, include it in `columns.dart` and extend `columns_schema_test.dart` is not needed (`updated_at`/`deleted_at` exist on every soft-deletable table; they're already validated per-table in Task 2).

---

### Task 7: Full verification + branch finish

- [ ] **Step 1: gen-l10n (parity sanity; no ARB change expected)**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat gen-l10n`
Expected: success, no diff.

- [ ] **Step 2: Analyze whole project**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat analyze`
Expected: No issues found!

- [ ] **Step 3: Full test suite (exclude pg locally)**

Run: `C:\Users\Kerro\flutter\bin\flutter.bat test --exclude-tags pg`
Expected: All pass. (In CI, pg-tagged `columns_schema_test.dart` runs against postgres:17.)

- [ ] **Step 4: Confirm no stray raw casts remain at the DB boundary**

Run: `grep -rnE "\] as String|!\.toString\(\)|_asDouble" lib/storage lib/features/canvas/models lib/features/generation lib/services | grep -v "\.freezed\.dart"`
Expected: zero DB-row decode hits (only out-of-scope provider-response / typeConfig hits, if any — note them for P1-4).

- [ ] **Step 5:** Use superpowers:requesting-code-review, then superpowers:finishing-a-development-branch → push + PR.

## Self-Review

- **Spec coverage (deep review P0#2 (a)+(b)):** (a) string column names → `*Col` constants (Task 2) adopted in `fromRow` (Tasks 3–5) and patch keys (Task 6); (b) typed row extractors converging scattered casts → `DbRow` (Task 1), applied at every DB-row decode (Tasks 3–5). pg guard catches wrong constant *values* (Task 2). ✅ ADR-0003 honored (Map edge kept; no freezed domain rows). ✅ `jobs.next_poll_at` correctly excluded (v4 drop).
- **Placeholder scan:** Tasks 1–4 carry full exact code. Tasks 5–6 are deliberately *parameterized mechanical sweeps* — the transform rule and the complete column inventory (Task 2) are fully specified; the per-file `fromRow` body must be read at execution because those files were not all read during planning. This is the one honest concession to file count, not a "TODO".
- **Type consistency:** `DbRow` method names (`reqString/optString/reqId/optId/reqInt/optInt/optDouble/optBool`) identical across Task 1 def and Tasks 3–6 uses. `*Col` class/field names identical across Task 2 def, the pg guard, and migration tasks. `LocalIOError(extra:)` shape matches `base_repository.dart`'s existing `guard()` usage.
- **Out of scope (other roadmap items):** P0#3 `SyncProviderBase`; P1-4 provider-response parsing; P1-5 perf/index (schema v5); frontend control-level debt.
