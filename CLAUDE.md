# InkFrame v2 — Project Rules

## Tech Stack

- **Framework**: Flutter Desktop (Dart)
- **State**: Riverpod (with code generation)
- **Storage**: Embedded PostgreSQL
- **Network**: dio
- **i18n**: flutter_localizations + ARB files
- **Video Export**: ffmpeg_kit_flutter
- **Platforms**: macOS + Windows

## Architecture Principles

### SOLID — No Exceptions

- **S**: Every class/widget has ONE responsibility. A widget that fetches data AND renders UI = violation.
- **O**: Open for extension, closed for modification. Use abstract classes/interfaces, not if-else chains.
- **L**: Subtypes must be substitutable. Every Provider implementation must honor the base contract.
- **I**: No fat interfaces. Split `GenerationProvider` into `Submittable`, `Pollable`, `Cancellable` if a provider doesn't support all.
- **D**: Depend on abstractions. Widgets never import concrete providers/repositories directly — always through DI.

### Dependency Injection (Riverpod)

- ALL services injected via Riverpod providers
- NO static singletons, NO global mutable state, NO `ServiceLocator` pattern
- Lifecycle managed by Riverpod: `autoDispose` for transient, `keepAlive` for singletons
- Every injectable must have an abstract interface (for testing)

```dart
// ✅ Correct
abstract class ProjectRepository {
  Future<Project> load(String id);
  Future<void> save(Project project);
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return PostgresProjectRepository(ref.watch(databaseProvider));
});

// ❌ Wrong — concrete dependency, no interface
final projectProvider = Provider((ref) {
  return PostgresProjectRepository(PostgresDatabase());
});
```

### IoC & Lifecycle

- Database connections: app-scoped (created once, disposed on exit)
- HTTP clients: app-scoped (shared dio instance)
- Repositories: app-scoped
- ViewModels/Controllers: screen-scoped (autoDispose)
- Generation jobs: managed by JobQueue, outlive screens

### Zero Backward Compatibility

- NO migration scripts for old data formats
- NO legacy support code
- NO deprecated APIs kept "just in case"
- If a schema changes, the old version is dead. Period.

## i18n — Zero Hardcoded Strings

### Rules

1. **Development language is English** — all keys and default values in English
2. **Every user-facing string** goes through i18n. No exceptions.
3. **Every commit** must have 100% zh-CN and en-US coverage
4. **CI check**: ARB files must have identical key sets (build fails otherwise)

### File Structure

```
lib/l10n/
├── app_en.arb          # English (source of truth)
├── app_zh.arb          # Chinese (must match all keys)
└── l10n.yaml           # Flutter gen-l10n config
```

### Usage

```dart
// ✅ Correct
Text(context.l10n.canvasNewNodeImage)
Text(context.l10n.generateButtonLabel)
ToastService.show(context.l10n.jobSubmitted(providerName))

// ❌ Wrong — hardcoded string
Text("New Image Node")
Text("生成")
ToastService.show("已提交到 $providerName")
```

### AI Prompts

System prompts for Gemini/providers also go through i18n:
```dart
final hint = context.l10n.geminiSystemPrompt;
```

### Adding a New String

1. Add key + English value to `app_en.arb`
2. Add key + Chinese value to `app_zh.arb`
3. Run `flutter gen-l10n`
4. Use `context.l10n.yourNewKey` in code
5. Both files must be updated in the same commit

## Zero Hardcoded Styles — Design Token System

### Rules

1. **Every color, font size, spacing, radius, shadow** comes from the theme/token system
2. **No inline `Color(0xFF...)` or `fontSize: 14`** in widget code
3. **All visual properties** defined in `lib/theme/` as tokens

### Token Structure

```
lib/theme/
├── tokens.dart         # Color, spacing, radius, shadow tokens
├── app_theme.dart      # ThemeData builder from tokens
├── typography.dart     # Text styles
└── components/         # Reusable styled components
    ├── ink_button.dart
    ├── ink_card.dart
    ├── ink_input.dart
    └── ...
```

### Usage

```dart
// ✅ Correct
Container(
  padding: EdgeInsets.all(InkSpacing.md),
  decoration: BoxDecoration(
    color: context.inkColors.surface2,
    borderRadius: BorderRadius.circular(InkRadius.lg),
    boxShadow: [InkShadow.card],
  ),
)

// ❌ Wrong — hardcoded values
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Color(0xFF2A2A3E),
    borderRadius: BorderRadius.circular(12),
  ),
)
```

### Components Over Primitives

```dart
// ✅ Correct — use design system component
InkCard(
  child: Text(context.l10n.nodeTitle),
)

// ❌ Wrong — raw Container with inline styles
Container(
  decoration: BoxDecoration(...),
  child: Text("Node Title"),
)
```

## Project Structure

```
lib/
├── main.dart                    # Entry point, ProviderScope
├── app.dart                     # MaterialApp, router, theme
├── l10n/                        # i18n ARB files
├── theme/                       # Design tokens, theme, components
├── core/                        # Shared abstractions
│   ├── di/                      # Provider definitions
│   ├── models/                  # Domain models (immutable, freezed)
│   ├── interfaces/              # Abstract repository/service interfaces
│   └── utils/                   # Pure utility functions
├── features/                    # Feature modules (vertical slices)
│   ├── canvas/                  # Node canvas
│   │   ├── models/
│   │   ├── providers/           # Riverpod state
│   │   ├── widgets/             # UI components
│   │   └── services/
│   ├── script/                  # Script editor + AI co-writing
│   ├── generation/              # Asset generation (人物/场景/道具)
│   ├── storyboard/              # Storyboard table
│   ├── assets/                  # Asset browser
│   ├── settings/                # Settings
│   └── jobs/                    # Job queue
├── providers/                   # AI provider implementations
│   ├── provider_interface.dart  # Abstract contract
│   ├── wanx_provider.dart
│   ├── banana_provider.dart
│   ├── kling_provider.dart
│   └── seedance_provider.dart
├── storage/                     # Database layer
│   ├── database.dart            # PG connection management
│   ├── repositories/            # Concrete repository implementations
│   └── schema.dart              # Table definitions
└── services/                    # App-level services
    ├── toast_service.dart
    ├── file_service.dart
    └── export_service.dart
```

## Code Rules

### Models

- ALL models use `freezed` for immutability + copyWith + JSON serialization
- NO mutable model classes
- NO `Map<String, dynamic>` as model substitute

### Error Handling

- Custom exception types per domain (ProviderException, StorageException, etc.)
- NO catching `Exception` or `dynamic` — always specific types
- Errors bubble up to UI via Riverpod AsyncValue

### Testing

- TDD: write test first, watch it fail, implement, watch it pass
- Every public method has a test
- Repositories tested with mock DB
- Providers tested with mock repositories
- Widgets tested with ProviderScope overrides

### Git

- Every commit must: compile clean, pass all tests, have full i18n coverage
- Commit messages: conventional commits (feat/fix/refactor/test/docs)
- No `--no-verify`, no skipping hooks

## Provider API Keys

- Stored in platform-secure storage (macOS Keychain / Windows Credential Manager)
- NEVER in code, config files, or database
- Access through `SecureStorageService` interface only
