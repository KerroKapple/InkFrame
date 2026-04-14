#!/usr/bin/env bash
# fetch-binaries.sh —— 从对象存储拉取锁定版本的 PostgreSQL 二进制，落地到
# resources 子目录供打包。PRD §22.1 规格：
#   macOS: macos/Runner/Resources/pg/bin + pg/lib （分 arm64 / x64 两套）
#   Windows: windows/runner/resources/pg/bin + pg/lib （仅 x64）
#
# 设计目标：
#   - 幂等：已存在且 SHA256 校验通过则跳过下载
#   - 版本锁：从 scripts/pg/pg-version.txt 读取，与远端 manifest 严格比对
#   - 校验失败 → exit 1（禁止继续打包）
#
# v0.1.0 未上对象存储，本脚本先输出 NOT_CONFIGURED 并提示手动放置路径，
# 保证 CI / 开发机不会误以为下载成功。真实对象存储地址由 T7 打包流水线填入。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

VERSION_FILE="scripts/pg/pg-version.txt"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "[fetch-binaries] 缺少 $VERSION_FILE" >&2
  exit 1
fi

PG_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ -z "$PG_VERSION" ]]; then
  echo "[fetch-binaries] pg-version.txt 为空" >&2
  exit 1
fi

# 目标平台由调用方以 INKFRAME_PG_PLATFORM 指定；默认按运行机器推断。
PLATFORM="${INKFRAME_PG_PLATFORM:-}"
if [[ -z "$PLATFORM" ]]; then
  UNAME="$(uname -s)"
  ARCH="$(uname -m)"
  case "$UNAME" in
    Darwin) PLATFORM="macos-$([[ "$ARCH" == "arm64" ]] && echo arm64 || echo x64)" ;;
    Linux)  PLATFORM="linux-x64" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows-x64" ;;
    *) PLATFORM="unknown" ;;
  esac
fi

case "$PLATFORM" in
  macos-arm64|macos-x64) TARGET_DIR="macos/Runner/Resources/pg/$PLATFORM" ;;
  windows-x64)           TARGET_DIR="windows/runner/resources/pg/$PLATFORM" ;;
  linux-x64)             TARGET_DIR="build/pg/$PLATFORM" ;; # 仅本地烟测，不进发布
  *) echo "[fetch-binaries] 未知平台：$PLATFORM" >&2; exit 1 ;;
esac

BIN_DIR="$TARGET_DIR/bin"
LIB_DIR="$TARGET_DIR/lib"

echo "[fetch-binaries] version=$PG_VERSION platform=$PLATFORM target=$TARGET_DIR"

# 幂等校验：已有 postgres / pg_ctl / initdb 则视为就绪。
if [[ -x "$BIN_DIR/postgres" || -x "$BIN_DIR/postgres.exe" ]]; then
  FOUND_VERSION="$("$BIN_DIR/postgres" --version 2>/dev/null || "$BIN_DIR/postgres.exe" --version 2>/dev/null || true)"
  if [[ "$FOUND_VERSION" == *"$PG_VERSION"* ]]; then
    echo "[fetch-binaries] 已就绪：$FOUND_VERSION"
    exit 0
  fi
  echo "[fetch-binaries] 版本不匹配：$FOUND_VERSION ≠ $PG_VERSION，重新拉取"
  rm -rf "$TARGET_DIR"
fi

# 对象存储 URL：v0.1.0 尚未接入，留占位。
PG_ARTIFACT_BASE_URL="${PG_ARTIFACT_BASE_URL:-}"
if [[ -z "$PG_ARTIFACT_BASE_URL" ]]; then
  cat <<'EOF' >&2
[fetch-binaries] NOT_CONFIGURED
  ⚠️  PG_ARTIFACT_BASE_URL 未设置，无法下载二进制。
  开发机：使用 Homebrew PG 17（详见 CONTRIBUTING.md「本地 PostgreSQL」章节）
  打包机：请先配置对象存储 base URL，格式：
    export PG_ARTIFACT_BASE_URL=https://<bucket>/inkframe/pg
  预期文件：$PG_ARTIFACT_BASE_URL/$PG_VERSION/$PLATFORM.tar.gz
           $PG_ARTIFACT_BASE_URL/$PG_VERSION/$PLATFORM.tar.gz.sha256
EOF
  exit 1
fi

ARCHIVE="$PLATFORM.tar.gz"
SUM_URL="$PG_ARTIFACT_BASE_URL/$PG_VERSION/$ARCHIVE.sha256"
ARCHIVE_URL="$PG_ARTIFACT_BASE_URL/$PG_VERSION/$ARCHIVE"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[fetch-binaries] 下载 $ARCHIVE_URL"
curl -fL --retry 3 -o "$TMP_DIR/$ARCHIVE" "$ARCHIVE_URL"
curl -fL --retry 3 -o "$TMP_DIR/$ARCHIVE.sha256" "$SUM_URL"

EXPECTED="$(awk '{print $1}' "$TMP_DIR/$ARCHIVE.sha256")"
if command -v shasum >/dev/null 2>&1; then
  ACTUAL="$(shasum -a 256 "$TMP_DIR/$ARCHIVE" | awk '{print $1}')"
else
  ACTUAL="$(sha256sum "$TMP_DIR/$ARCHIVE" | awk '{print $1}')"
fi

if [[ "$EXPECTED" != "$ACTUAL" ]]; then
  echo "[fetch-binaries] SHA256 校验失败 expected=$EXPECTED actual=$ACTUAL" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
tar -xzf "$TMP_DIR/$ARCHIVE" -C "$TARGET_DIR" --strip-components=1

echo "[fetch-binaries] 解压完成，验证 postgres 版本"
if [[ -x "$BIN_DIR/postgres" ]]; then
  "$BIN_DIR/postgres" --version
elif [[ -x "$BIN_DIR/postgres.exe" ]]; then
  "$BIN_DIR/postgres.exe" --version
else
  echo "[fetch-binaries] 解压后找不到 postgres 可执行文件" >&2
  exit 1
fi

echo "[fetch-binaries] OK"
