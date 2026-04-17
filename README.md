# InkFrame

开源本地优先的 AI 影视创作工作站（Flutter Desktop，macOS + Windows）。

## Tech Stack

- **Framework**: Flutter Desktop (Dart ≥ 3.11, Flutter ≥ 3.41)
- **State**: Riverpod 2.x（含代码生成）
- **Storage**: Embedded PostgreSQL
- **Network**: dio（T3 起落地）
- **i18n**: flutter_localizations + ARB（en 为 source of truth，zh 同步）
- **Video Export**: ffmpeg_kit_flutter（T6+）

## Development Setup

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 安装 Git Hooks（**必做**）

Hooks 脚本放在 `scripts/hooks/` 下，受版本控制。首次 clone 后必须手动链接到 `.git/hooks`：

```bash
ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit
ln -sf ../../scripts/hooks/pre-push   .git/hooks/pre-push
```

- `pre-commit` 运行 `flutter analyze` + 5 个硬规则检查（i18n / tokens / magic strings / 直接实例化 / Disposable 清理），任一失败阻断 commit
- `pre-push` 运行 `flutter test`，失败阻断 push

### 3. 本地验证

```bash
flutter analyze             # 必须 0 warning
flutter test --coverage     # 含覆盖率
lcov --summary coverage/lcov.info
```

## Architecture

详见 [docs/CLAUDE.md](docs/CLAUDE.md)（SOLID / DI / i18n / Design Tokens 规则）与 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## Contributing

见 [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)。
