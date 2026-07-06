#!/usr/bin/env bash
# macOS 签名 + 公证 —— BUILD-RELEASE §5 的可执行实现。
# 骨架契约：凭据齐全才执行；缺关键凭据 → 打印 SKIPPED 退出 0（不阻断流水线，
# 等用户提供 Developer ID 证书后本步骤自动生效）。
#
# 环境变量（由 release.yml 从 GitHub Secrets 注入）：
#   MACOS_CERT_P12_BASE64        Developer ID Application 证书（.p12）base64
#   MACOS_CERT_PASSWORD          .p12 导出密码
#   MACOS_SIGN_IDENTITY          签名身份，如 "Developer ID Application: Name (TEAMID)"
#   APPLE_ID / APPLE_TEAM_ID / APPLE_APP_SPECIFIC_PASSWORD   公证用（notarytool）
set -euo pipefail
cd "$(cd "$(dirname "$0")/../.." && pwd)"

if [[ -z "${MACOS_CERT_P12_BASE64:-}" ]]; then
  echo "[sign-macos] SKIPPED —— 未配置 MACOS_CERT_P12_BASE64（签名/公证凭据缺失）。"
  echo "[sign-macos] 产物保持 unsigned；配置 Developer ID 证书后本步骤自动生效。"
  exit 0
fi

APP="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -1)"
if [[ -z "$APP" ]]; then
  echo "[sign-macos] 找不到 .app —— 先 flutter build macos --release" >&2
  exit 1
fi

: "${MACOS_SIGN_IDENTITY:?需要 MACOS_SIGN_IDENTITY（签名身份）}"
: "${RUNNER_TEMP:=$(mktemp -d)}"

# 1) 导入证书到临时 keychain（CI 隔离，trap 清理）
KEYCHAIN="$RUNNER_TEMP/inkframe-signing.keychain-db"
KEYCHAIN_PW="$(openssl rand -base64 24)"
security create-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
echo "$MACOS_CERT_P12_BASE64" | base64 --decode > "$RUNNER_TEMP/cert.p12"
security import "$RUNNER_TEMP/cert.p12" -k "$KEYCHAIN" -P "$MACOS_CERT_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PW" "$KEYCHAIN" >/dev/null
# 把临时 keychain 加入搜索域（保留原有，避免覆盖）
EXISTING="$(security list-keychains -d user | sed -e 's/\"//g' -e 's/^[[:space:]]*//')"
# shellcheck disable=SC2086
security list-keychains -d user -s "$KEYCHAIN" $EXISTING
trap 'security delete-keychain "$KEYCHAIN" 2>/dev/null || true; rm -f "$RUNNER_TEMP/cert.p12"' EXIT

# 2) 深度签名（嵌入的 PG 二进制 + libmpv dylib 一起签）+ hardened runtime
echo "[sign-macos] codesign --deep $APP"
codesign --deep --force --options runtime \
  --entitlements macos/Runner/Release.entitlements \
  --sign "$MACOS_SIGN_IDENTITY" \
  --timestamp \
  "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# 3) 公证（优先公证 DMG，没有则公证 .app 的 zip）
mkdir -p dist
DMG="$(find dist -maxdepth 1 -name '*.dmg' | head -1 || true)"
if [[ -n "$DMG" ]]; then
  NOTARIZE_TARGET="$DMG"
else
  NOTARIZE_TARGET="$RUNNER_TEMP/inkframe-notarize.zip"
  ditto -c -k --keepParent "$APP" "$NOTARIZE_TARGET"
fi

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "[sign-macos] notarytool submit $NOTARIZE_TARGET"
  xcrun notarytool submit "$NOTARIZE_TARGET" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
  # staple 只能装订 .app / .dmg / .pkg（不能装订 zip）
  if [[ -n "$DMG" ]]; then xcrun stapler staple "$DMG"; else xcrun stapler staple "$APP"; fi
  echo "[sign-macos] 签名 + 公证完成 ✅"
else
  echo "[sign-macos] 已签名；缺 APPLE_ID/TEAM_ID/APP_SPECIFIC_PASSWORD —— 跳过公证。"
fi
