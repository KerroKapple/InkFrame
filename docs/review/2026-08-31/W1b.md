# W1b — core DI wiring + app entry point

**CONCLUSION**: 10 findings — P0: 0, P1: 1, P2: 5, P3: 4. Clean after falsification: constants and licenses, routing precedence/onboarding decisions, repository/HTTP-client/JobQueue app lifecycles, proxy credential/NO_PROXY parsing, and the prohibition on static/global mutable state in `di/**`.

## Findings

### [P1] Restore can race the schema bootstrap during normal startup
- **File**: lib/core/di/database_restore.dart:100; lib/app.dart:112
- **Issue**: The restore flow waits for the raw pool, not the migrated-pool barrier, while the startup gate exposes the interactive shell during migration.
- **Evidence**: `_StartupGate` sends both `AsyncLoading` and `AsyncData` to `_UnlockedShell`. `DatabaseRestoreFlow` then awaits `pgPoolProvider.future`; that future resolves before `DatabaseBootstrap.run()` completes in `pgMigratedPoolProvider`. The restore-flow tests delay only `pgPoolProvider`, and the routing tests deliberately keep `pgMigratedPoolProvider` loading without exercising restore.
- **Impact**: During a slow first launch, a user can reach Settings and start restore while schema DDL is still running. The flow may run `pg_dump`, close the pool, or swap databases underneath the migration, producing a partial safety backup, failed migration, or inconsistent restored state.
- **Suggested fix**: While migrated state is loading, await `pgMigratedPoolProvider.future` before backup/restore. Retain raw-pool recovery only for an established `AsyncError`, or disable DB maintenance controls until readiness is settled. Add a combined loading-gate/restore test.

### [P2] An empty HTTPS proxy variable disables a valid HTTP proxy globally
- **File**: lib/core/net/proxy_env.dart:50
- **Issue**: `applyEnvProxy` uses the precedence-aware `_firstSet` to decide whether to install `findProxy`.
- **Evidence**: For `HTTPS_PROXY=''` and `HTTP_PROXY='http://proxy:8080'`, `_firstSet` stops at the empty HTTPS value and returns `null`, so the adapter is untouched. However, `proxyRuleFor` correctly selects `HTTP_PROXY` for an HTTP URL. Thus the pure decision function and actual Dio wiring disagree.
- **Impact**: HTTP requests silently bypass the configured proxy in mixed explicit-disable configurations.
- **Suggested fix**: Determine adapter activation by checking whether any proxy variable independently contains a non-empty value; keep `_firstSet` only for per-request precedence. Add an `applyEnvProxy` test covering empty HTTPS plus non-empty HTTP/ALL proxy.

### [P2] Blank or relative environment roots can move data into the process working directory
- **File**: lib/core/paths/app_paths.dart:62
- **Issue**: Platform roots are accepted whenever non-null; blank and relative values are not rejected. Blank `HOME` also prevents fallback to `USERPROFILE`.
- **Evidence**: `p.join('', 'InkFrame')` produces a relative `InkFrame` path. `main.dart` treats any non-null conventional path as migration-safe, so a real legacy root can be renamed into that relative location.
- **Impact**: A stripped or malformed launch environment can place—and during DIR-1, move—the workspace under the current working directory, potentially an installation directory or an attacker-influenced relative path.
- **Suggested fix**: Trim values, treat empty values as missing, require an absolute root, and otherwise use `path_provider`. Let `legacyRootPath` skip blank `HOME` and try `USERPROFILE`. Test blank and relative values.

### [P2] Legacy-root inspection errors escape the migration fallback
- **File**: lib/core/paths/legacy_root_migrator.dart:65
- **Issue**: `_legacyHasRealData()` performs `Directory.list()` outside the migration's `FileSystemException` guard.
- **Evidence**: Both the healthy-target branch at line 69 and pre-rename branch at line 74 call the scanner before the `try` beginning at line 80. Permission errors or an unreadable/stale legacy link therefore escape `migrate()`.
- **Impact**: Even when the conventional target is healthy, an inaccessible leftover `~/InkFrame` can abort startup before `runApp` and before the file logger is ready.
- **Suggested fix**: Guard legacy inspection separately. When the target exists, inspection failure should not prevent using it; record a diagnostic outcome for later logging. Add an injected/scanner failure test.

### [P2] PNG probing accepts truncated headers and dimensions outside the PNG limit
- **File**: lib/core/media/png_dimensions.dart:12
- **Issue**: The parser accepts only 24 bytes, ignores the rest of IHDR and its CRC, and accepts unsigned dimensions above `2^31-1`.
- **Evidence**: A signature plus length/type/width/height returns a size even when bytes 24–32 are absent. `_readUint32` can also return `0xffffffff`, while validation rejects only zero. Existing tests use a zero CRC and test truncation only at 23 bytes.
- **Impact**: Corrupt output can receive trusted metadata. Dimensions above `2147483647` can then be written to PostgreSQL `INTEGER` width/height columns, turning otherwise persisted output into a database failure.
- **Suggested fix**: Require the complete 33-byte IHDR, enforce `1..0x7fffffff`, validate IHDR fields, and preferably verify CRC. Add 24–32-byte truncation, bad CRC, and high-bit dimension tests.

### [P2] File-logger failures can defeat the pre-reporter startup fallback
- **File**: lib/core/logging/logger_service.dart:137; lib/main.dart:268
- **Issue**: Synchronous directory/stat/write/rotation operations can throw. Before `CrashReporter` exists, the zone handler retries the same logger before writing to stderr.
- **Evidence**: `_writeLine` has no I/O guard. The first lifecycle log occurs before reporter construction; if it fails due to disk-full, permissions, or a locked path, the zone handler calls `l?.error(...)`, which can throw again and prevent lines 270–271 from executing.
- **Impact**: Startup can terminate with neither the application nor the promised stderr diagnostic, specifically when logging storage is unavailable.
- **Suggested fix**: Make logging I/O best-effort or surface a safe fallback sink. Independently wrap the pre-reporter `l.error` call so stderr is always reached. Add failing-filesystem logger tests.

### [P3] Malformed JSON escapes the typed database decoding boundary
- **File**: lib/core/db/row_reader.dart:94
- **Issue**: `stringList` promises `LocalIOError` for invalid input but lets `jsonDecode` throw `FormatException`.
- **Evidence**: Only successfully decoded non-list values reach `_decodeError`; malformed JSON bypasses it. `row_reader_test.dart` does not exercise `stringList`.
- **Impact**: Snapshot, fake, or import-backed rows can emit an unexpected raw exception instead of the repository's diagnosable decode error.
- **Suggested fix**: Catch `FormatException` and throw `_decodeError`; add decoded-list, malformed-JSON, and decoded-non-list tests.

### [P3] DI exposes concrete lifecycle coordinators instead of abstract contracts
- **File**: lib/core/di/database.dart:31; lib/core/di/database_restore.dart:45
- **Issue**: `pgControllerProvider` publishes concrete `PgController`, and `databaseRestoreFlowProvider` publishes concrete `DatabaseRestoreFlow`, which also retains a raw Riverpod `Ref`.
- **Evidence**: UI, teardown, backup, and restore code directly consume these concrete types. Tests must `implements PgController`, coupling fakes to every member of a production class.
- **Impact**: Lifecycle implementation changes propagate across UI and tests, violating the documented "every injectable has an abstract interface" rule.
- **Suggested fix**: Introduce narrow lifecycle and restore-coordinator interfaces, bind implementations only in `di/**`, and keep raw pool/controller mechanics behind them.

### [P3] CanvasStyleController is retained for the entire application lifetime
- **File**: lib/core/di/canvas_style.dart:59
- **Issue**: A screen-facing controller is declared with plain `NotifierProvider`, making it keep-alive rather than screen-scoped `autoDispose`.
- **Evidence**: Unlike theme and locale, it is not watched by the app root; it is used only by Canvas and Settings. Its durable source is already `PreferencesService`, so reconstruction is safe.
- **Impact**: After either screen first opens, the notifier remains resident and may preserve stale state if preferences change through another path, contrary to the lifecycle table.
- **Suggested fix**: Use `NotifierProvider.autoDispose` and test that leaving the last consumer disposes it and rebuilding re-seeds from preferences.

### [P3] Package metadata is fetched twice
- **File**: lib/main.dart:141; lib/core/di/package_info.dart:5
- **Issue**: `main` eagerly obtains `PackageInfo` for crash reporting but does not inject that value into `packageInfoProvider`.
- **Evidence**: The `ProviderContainer` overrides at lines 185–192 omit `packageInfoProvider`, whose default calls `PackageInfo.fromPlatform()` again when update checking, About, diagnostics, or project export first reads it.
- **Impact**: An unnecessary second platform-channel call and duplicate `PackageInfo` instance occur during normal use/startup update checks.
- **Suggested fix**: Override `packageInfoProvider` with the already-loaded `pkg` value, or centralize the initial read through one shared bootstrap future.
