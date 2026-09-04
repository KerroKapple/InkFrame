# W1a — core errors/interfaces/models

**CONCLUSION**: 8 findings — P0: 0, P1: 0, P2: 4, P3: 4. The 15 InkError codes, wire values, retryability set, sealed subclasses, message-key mappings, and localization routing are exhaustive and well tested. CustomProviderConfig JSON round-tripping and generated Freezed copyWith/outer collection wrappers are also clean. The board's tracked JobRepository fat-interface debt is not repeated below.

## Findings

### [P2] JobStatus permits states that violate persistence and success invariants
- **File**: lib/core/models/job_status.dart:17
- **Issue**: `inProgress` documents `progress ∈ [0,1]`, while `success` means an asset was produced, but neither invariant is enforced.
- **Evidence**:
  ```dart
  const factory JobStatus.inProgress({
    @Default(0.0) double progress,
  }) = JobInProgress;

  const factory JobStatus.success({
    required List<String> remoteUrls,
    List<Uint8List>? inlineBytes,
  }) = JobSuccess;
  ```
  `JobStatus.inProgress(progress: 1.1)` and `JobStatus.success(remoteUrls: [])` are valid. JobQueue persists progress into a database column constrained to `0.0..1.0`. Its zero-output guard applies only when `batchSize > 1`; a single-item empty success is transitioned to success without media. Scoped tests cover only valid progress and do not reject empty success.
- **Impact**: A provider can cause a database constraint failure merely by reporting out-of-range progress, or produce a successful job/result node with no downloadable or inline artifact.
- **Suggested fix**: Validate provider results at the JobQueue boundary using release-mode checks. Represent success as explicit non-empty remote/inline variants, or reject a success for which both channels are empty.

### [P2] Numeric but invalid text scales survive tolerant preference parsing
- **File**: lib/core/models/app_preferences.dart:129
- **Issue**: `fromMap` promises that illegal values fall back to defaults, but any numeric `text_scale` is accepted without range or finiteness validation.
- **Evidence**:
  ```dart
  textScale: ts is num ? ts.toDouble() : 1.0,
  ```
  The settings slider accepts only `0.85..1.40`, and typography multiplies every font size by this value. Existing tests cover null/type errors, not numeric values outside the supported range.
- **Impact**: A valid but manually edited or stale preferences file containing `"text_scale": 2`, `0`, or a negative value seeds invalid UI state. Opening Settings can violate the Slider's range assertion, while zero/negative values create invalid typography.
- **Suggested fix**: Accept only finite values within `0.85..1.40`; otherwise use `1.0` or clamp consistently. Add range, NaN, and infinity tests.

### [P2] ProviderRegistry erases mandatory provider facets
- **File**: lib/core/interfaces/provider_registry.dart:9; lib/core/interfaces/generation_provider.dart:18
- **Issue**: The registry factory and lookup return only `Submittable`, although consumers assume every registered provider is also `Pollable` and `KeyValidatable`.
- **Evidence**:
  ```dart
  typedef ProviderFactory = Submittable Function();
  Submittable get(String providerId);
  ```
  `generation_provider.dart` says all providers must support key validation. Nevertheless, JobQueue rejects a registered non-`Pollable` only after submission, while API-key settings treat a non-`KeyValidatable` provider as successfully validated. The repository's `FakeSubmittable` proves such an implementation is accepted statically. Current production providers happen to implement all three facets, but the contract does not enforce that.
- **Impact**: A replacement provider valid under `ProviderRegistry` can fail every generation after submission, or have an invalid key saved and reported as verified without validation.
- **Suggested fix**: Define a composed mandatory provider type implementing `Submittable`, `Pollable`, and `KeyValidatable`, and return that from the registry. Keep genuinely optional facets such as `Cancellable` separate.

### [P2] VideoPlayerHandle exposes an Object with a hidden media_kit requirement
- **File**: lib/core/interfaces/video_player_service.dart:25
- **Issue**: `rawPlayer` claims to avoid leaking media_kit, but consumers require the object to be a media_kit `Player`.
- **Evidence**:
  ```dart
  Object get rawPlayer;
  ```
  Both video UIs perform `if (raw is Player) VideoController(raw)`. Any otherwise valid `VideoPlayerHandle` returning another backend object cannot render. The sequence-preview fake returns `Object()` and therefore cannot exercise the rendered-video path.
- **Impact**: Alternative backends and complete test doubles satisfy the interface but yield an endless loading/placeholder surface. The implementation is not substitutable despite the abstraction.
- **Suggested fix**: Either make the concrete dependency explicit and typed, or abstract controller/surface creation so UI never inspects a backend object.

### [P3] SemVer.tryParse can throw and accepts versions forbidden by SemVer 2.0
- **File**: lib/core/models/semver.dart:25
- **Issue**: The parser promises invalid input returns null, but its regex accepts arbitrary-length numeric fields and leading-zero numeric identifiers.
- **Evidence**:
  ```dart
  r'^v?(\d+)\.(\d+)\.(\d+)...'
  ...
  major: int.parse(m.group(1)!),
  ```
  An oversized numeric component can make `int.parse` throw `FormatException`. Values such as `01.2.3` and `1.2.3-alpha.01` are accepted even though SemVer forbids leading zeroes. Tests omit both cases.
- **Impact**: One malformed GitHub release tag can abort the entire update check instead of being skipped, leaking a raw non-InkError despite the service contract.
- **Suggested fix**: Use `int.tryParse`, reject oversized components, and tighten core/prerelease numeric patterns to disallow leading zeroes.

### [P3] Core "immutable" values expose writable payloads
- **File**: lib/core/errors/ink_error.dart:74; lib/core/models/import_plan_data.dart:26; lib/core/models/job_status.dart:30
- **Issue**: Several values retain and publicly expose mutable collections.
- **Evidence**:
  ```dart
  final Map<String, Object?> extra;
  final Map<String, String> canvasIdMap;
  final List<Map<String, Object?>> nodes;
  List<Uint8List>? inlineBytes;
  ```
  `ImportPlanData` has no defensive wrappers at any level. Freezed protects the outer `inlineBytes` list, but each `Uint8List` remains writable. `InkError.extra` is directly mutable despite `InkError` being annotated immutable. No scoped test attempts mutation or retained-input aliasing.
- **Impact**: Import rows can change after remapping but before transactional insertion; provider byte buffers can change between status emission and persistence; error reasons/log data can change after construction.
- **Suggested fix**: Defensively copy and expose unmodifiable collections, establish immutable byte ownership or copy-on-read semantics, and add mutation/aliasing tests.

### [P3] Tagged result classes admit contradictory success states
- **File**: lib/core/interfaces/database_backup_service.dart:61; lib/core/interfaces/project_import_service.dart:27
- **Issue**: Nullable payloads encode invariants only in comments:
  ```dart
  const BackupNowResult({required this.outcome, this.fileName});
  const ImportResult({required this.outcome, this.newProjectId, this.reason});
  ```
  Thus `BackupNowResult(outcome: created)` and `ImportResult(outcome: imported)` are valid despite lacking their required success payloads. Current concrete implementations honor the convention, but alternative implementations and fakes are not forced to.
- **Impact**: Import UI can show success while selecting a null project ID. Restore flow can believe its safety backup succeeded while losing the filename needed for diagnosis/recovery.
- **Suggested fix**: Use Freezed sealed variants such as `created(fileName)`/`failed(outcome)` and `imported(projectId)`/`failed(outcome, reason)`.

### [P3] Transaction and repository interfaces remain client-fat
- **File**: lib/core/interfaces/unit_of_work.dart:19; lib/core/interfaces/node_repository.dart:2
- **Issue**: `RepositoryScope` requires nine unrelated repositories, while `NodeRepository` combines ordinary CRUD, type-config mutation, startup cleanup, and orphan-media scanning.
- **Evidence**: The shared `FakeRepositoryScope` must carry nine nullable repositories and implement nine getters that throw `StateError` when omitted. Numerous narrow NodeRepository fakes implement unused methods with `UnimplementedError` or `noSuchMethod`. This is separate from the JobRepository debt already tracked on the board.
- **Impact**: Adding one transactional repository forces every scope implementation and harness to change. Narrow tests compile with runtime holes, so an accidental new call fails at runtime rather than being excluded by the dependency type.
- **Suggested fix**: Compose narrow transaction-scope interfaces per use case, and split Node CRUD/type-config operations from startup and media-GC queries.
