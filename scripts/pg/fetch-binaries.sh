#!/usr/bin/env bash
# fetch-binaries.sh —— 嵌入式 PostgreSQL 二进制置备（PKG-2A）。
# 落点（与 PgBinaryLocator 约定一致）：
#   macOS:   macos/Runner/Resources/pg/<platform>/{bin,lib,share}
#   Windows: windows/runner/resources/pg/windows-x64/{bin,lib,share}
#
# 两种模式：
#   upstream（默认，方案 A，零配置零用户动作）：
#     windows-x64  EDB 官方 zip 直拉，URL+SHA256 锁定在 scripts/pg/upstream.lock；
#                  只取 pgsql/{bin,lib,share} 并裁掉 share/{doc,man,locale}
#     macos-*      Homebrew postgresql@<major> → make-relocatable-macos.sh 生成
#                  自洽可分发目录（brew 补丁位浮动 → 只做主版本匹配）
#     linux-x64    不支持（仅本地烟测平台，用系统 PG 或 bucket 模式）
#   bucket（方案 B 覆盖）：设 PG_ARTIFACT_BASE_URL 时从对象存储拉
#     $BASE/$VERSION/$PLATFORM.tar.gz（+ .sha256），语义与历史版本一致
#
# 不变量：
#   - 落位原子：装配+校验全在 <target>.partial，通过后才对换；任何失败零残留
#   - 校验统一：必需工具（postgres/initdb/pg_ctl/pg_dump/pg_restore，PgBinaryLocation
#     契约）+ 版本匹配（windows/bucket 精确含 pg-version.txt；macos upstream 主版本）
#   - 幂等：现存目标通过同一校验即短路退出，不重复下载
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

VERSION_FILE="scripts/pg/pg-version.txt"
LOCK_FILE="scripts/pg/upstream.lock"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "[fetch-binaries] 缺少 $VERSION_FILE" >&2
  exit 1
fi
PG_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ -z "$PG_VERSION" ]]; then
  echo "[fetch-binaries] pg-version.txt 为空" >&2
  exit 1
fi
PG_MAJOR="${PG_VERSION%%.*}"

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
  macos-arm64|macos-x64) TARGET_DIR="macos/Runner/Resources/pg/$PLATFORM"; EXE="" ;;
  windows-x64)           TARGET_DIR="windows/runner/resources/pg/$PLATFORM"; EXE=".exe" ;;
  linux-x64)             TARGET_DIR="build/pg/$PLATFORM"; EXE="" ;; # 仅本地烟测，不进发布
  *) echo "[fetch-binaries] 未知平台：$PLATFORM" >&2; exit 1 ;;
esac
PARTIAL_DIR="$TARGET_DIR.partial"

MODE=upstream
[[ -n "${PG_ARTIFACT_BASE_URL:-}" ]] && MODE=bucket

echo "[fetch-binaries] version=$PG_VERSION platform=$PLATFORM mode=$MODE target=$TARGET_DIR"

REQUIRED_TOOLS=(postgres initdb pg_ctl pg_dump pg_restore)

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

lock_get() {
  local key="$1" val
  # tr -d '\r'：防 CRLF 形态工作树把行尾混进 URL/SHA（.gitattributes 已锁 LF，此为双保险）
  val="$(sed -n "s/^${key}=//p" "$LOCK_FILE" 2>/dev/null | head -1 | tr -d '\r')"
  if [[ -z "$val" ]]; then
    echo "[fetch-binaries] $LOCK_FILE 缺少 ${key}" >&2
    return 1
  fi
  echo "$val"
}

# 校验一棵已装配的 PG 目录：必需工具齐全 + lib/share 在位 + 版本匹配。$1=目录
verify_tree() {
  local dir="$1" t ver
  for t in "${REQUIRED_TOOLS[@]}"; do
    if [[ ! -f "$dir/bin/$t$EXE" ]]; then
      echo "[fetch-binaries] 校验失败：缺 bin/$t$EXE（$dir）" >&2
      return 1
    fi
  done
  # initdb 运行必需 share（postgres.bki/timezone），postgres 运行必需 lib——残缺树不得短路
  for t in lib share; do
    if [[ ! -d "$dir/$t" ]]; then
      echo "[fetch-binaries] 校验失败：缺 $t/ 目录（$dir）" >&2
      return 1
    fi
  done
  ver="$("$dir/bin/postgres$EXE" --version 2>/dev/null || true)"
  if [[ "$MODE" == "upstream" && "$PLATFORM" == macos-* ]]; then
    # brew 补丁位浮动（17.x），只锁主版本
    if ! grep -qE "\(PostgreSQL\) ${PG_MAJOR}\." <<<"$ver"; then
      echo "[fetch-binaries] 校验失败：版本主号不匹配 got='$ver' want major=$PG_MAJOR" >&2
      return 1
    fi
  else
    # 版本号右侧锚定：17.2 不得被 17.20/17.21 满足
    if ! grep -qE "\(PostgreSQL\) ${PG_VERSION//./\\.}([^0-9]|$)" <<<"$ver"; then
      echo "[fetch-binaries] 校验失败：版本不匹配 got='$ver' want=$PG_VERSION" >&2
      return 1
    fi
  fi
  echo "$ver"
}

# 陈旧 .partial（上次进程被杀的残留）先清，不受下方幂等短路遮蔽
rm -rf "$PARTIAL_DIR"

# 幂等短路：现存目标过同一校验即无事可做。
if [[ -d "$TARGET_DIR" ]]; then
  if READY_VER="$(verify_tree "$TARGET_DIR")"; then
    echo "[fetch-binaries] 已就绪：$READY_VER"
    exit 0
  fi
  echo "[fetch-binaries] 现存目标未过校验，重建"
  rm -rf "$TARGET_DIR"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$PARTIAL_DIR"' EXIT

download() { # $1=url $2=输出路径
  echo "[fetch-binaries] 下载 $1"
  curl -fL --retry 3 -o "$2" "$1"
}

extract_zip() { # $1=zip $2=目标目录
  mkdir -p "$2"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "$1" -d "$2"
  elif command -v 7z >/dev/null 2>&1; then
    7z x -y -o"$2" "$1" >/dev/null
  else
    powershell.exe -NoProfile -Command \
      "Expand-Archive -LiteralPath '$(cygpath -w "$1")' -DestinationPath '$(cygpath -w "$2")'"
  fi
}

fetch_bucket() {
  local archive="$PLATFORM.tar.gz" expected actual
  download "$PG_ARTIFACT_BASE_URL/$PG_VERSION/$archive" "$TMP_DIR/$archive"
  download "$PG_ARTIFACT_BASE_URL/$PG_VERSION/$archive.sha256" "$TMP_DIR/$archive.sha256"
  expected="$(awk '{print $1}' "$TMP_DIR/$archive.sha256")"
  actual="$(sha256_of "$TMP_DIR/$archive")"
  if [[ "$expected" != "$actual" ]]; then
    echo "[fetch-binaries] SHA256 校验失败 expected=$expected actual=$actual" >&2
    exit 1
  fi
  mkdir -p "$PARTIAL_DIR"
  tar -xzf "$TMP_DIR/$archive" -C "$PARTIAL_DIR" --strip-components=1
}

fetch_upstream_windows() {
  local url sha actual
  url="$(lock_get WINDOWS_X64_URL)"
  sha="$(lock_get WINDOWS_X64_SHA256)"
  download "$url" "$TMP_DIR/pg.zip"
  actual="$(sha256_of "$TMP_DIR/pg.zip")"
  if [[ "$sha" != "$actual" ]]; then
    echo "[fetch-binaries] SHA256 校验失败（EDB 包被变更或下载损坏）expected=$sha actual=$actual" >&2
    echo "                 上游 URL 若已失效，更新 $LOCK_FILE 并重新实测锁定。" >&2
    exit 1
  fi
  extract_zip "$TMP_DIR/pg.zip" "$TMP_DIR/extract"
  if [[ ! -d "$TMP_DIR/extract/pgsql/bin" ]]; then
    echo "[fetch-binaries] EDB zip 布局异常：缺 pgsql/bin（上游打包结构变了？）" >&2
    exit 1
  fi
  # 只取运行所需三目录（pgAdmin/StackBuilder/include/doc/symbols 全部不拷），再裁运行期无用物：
  #   share/{doc,man,locale}    文档与 NLS
  #   lib/*.lib                 MSVC 导入库（构建期产物）
  #   bin/wx*.dll               StackBuilder 的 wxWidgets GUI 依赖（PG 本体不加载）
  mkdir -p "$PARTIAL_DIR"
  cp -R "$TMP_DIR/extract/pgsql/bin" "$TMP_DIR/extract/pgsql/lib" "$TMP_DIR/extract/pgsql/share" "$PARTIAL_DIR/"
  rm -rf "$PARTIAL_DIR/share/doc" "$PARTIAL_DIR/share/man" "$PARTIAL_DIR/share/locale"
  rm -f "$PARTIAL_DIR"/lib/*.lib "$PARTIAL_DIR"/bin/wx*.dll
  chmod -R u+x "$PARTIAL_DIR/bin" # zip 不保执行位（Windows 本机无害，CI/测试环境必需）
}

fetch_upstream_macos() {
  local formula="postgresql@$PG_MAJOR" src=""
  if command -v brew >/dev/null 2>&1; then
    src="$(brew --prefix "$formula" 2>/dev/null || true)"
  fi
  if [[ -z "$src" || ! -x "$src/bin/postgres" ]]; then
    echo "[fetch-binaries] 找不到 Homebrew $formula（src='$src'）" >&2
    echo "                 先 brew install $formula 再重跑（CI 由 release.yml 安装）。" >&2
    exit 1
  fi
  bash "$REPO_ROOT/scripts/pg/make-relocatable-macos.sh" "$src" "$REPO_ROOT/$PARTIAL_DIR"
}

case "$MODE:$PLATFORM" in
  bucket:*)                fetch_bucket ;;
  upstream:windows-x64)    fetch_upstream_windows ;;
  upstream:macos-*)        fetch_upstream_macos ;;
  upstream:linux-x64)
    echo "[fetch-binaries] linux-x64 无 upstream 源（仅本地烟测平台）：" >&2
    echo "                 用系统 PG（SETUP.md），或设 PG_ARTIFACT_BASE_URL 走对象存储。" >&2
    exit 1
    ;;
esac

if ! FINAL_VER="$(verify_tree "$PARTIAL_DIR")"; then
  echo "[fetch-binaries] 装配产物未过校验，放弃（零残留）" >&2
  exit 1
fi
mv "$PARTIAL_DIR" "$TARGET_DIR"
echo "[fetch-binaries] OK $FINAL_VER → $TARGET_DIR"
