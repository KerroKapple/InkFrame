#!/usr/bin/env bash
# macOS DMG 打包 —— BUILD-RELEASE §6 骨架。
# best-effort：create-dmg 不可用或失败不阻断流水线（release.yml 该步标 continue-on-error）。
# GA 前应转为硬要求并接入 assets/dmg-background.png 等品牌资源。
set -euo pipefail
cd "$(cd "$(dirname "$0")/../.." && pwd)"

APP="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -1)"
[[ -n "$APP" ]] || { echo "[dmg] 找不到 .app" >&2; exit 1; }

VERSION="${BUILD_NAME:-0.0.0-dev}"
mkdir -p dist
OUT="dist/InkFrame-$VERSION-macos-arm64.dmg"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "[dmg] create-dmg 未安装 —— brew install create-dmg"
  brew install create-dmg
fi

STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
cp THIRD-PARTY.md "$STAGE/"   # LEG-1 ④：DMG 根含许可 NOTICE
# 最小布局（无自定义背景，避免缺资源导致失败）；品牌化布局见 BUILD-RELEASE §6。
create-dmg \
  --volname "InkFrame $VERSION" \
  --window-size 800 400 \
  --icon-size 100 \
  --app-drop-link 600 185 \
  "$OUT" "$STAGE"
echo "[dmg] 输出：$OUT"
