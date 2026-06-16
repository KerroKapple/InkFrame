#!/usr/bin/env bash
# make-relocatable-macos.sh —— 从本机 Homebrew PostgreSQL 生成「可重定位」的嵌入式 PG，
# 落地到 macos/Runner/Resources/pg/macos-<arch>/，供 app bundle 打包。
#
# 为什么需要：Homebrew 的 postgres/initdb/pg_ctl 通过绝对路径（/opt/homebrew/...）
# 链接外部 dylib（icu / openssl / krb5 / lz4 / zstd / gettext），icu 等还用
# @loader_path 互相引用同伴库。直接拷进 .app 后在无 Homebrew 的用户机加载失败。
# 本脚本递归求出整个依赖闭包（含 @loader_path 解析）vendoring 进 lib/，用
# install_name_tool 把所有引用改写为 @rpath/<name>，并 ad-hoc 重签名，使其自洽可分发。
#
# 目录结构：
#   bin/                可执行（postgres/initdb/pg_ctl ...）
#   lib/                外部依赖闭包（icu/ssl/...，flat）
#   lib/postgresql/     PG 自带模块（plpgsql 等）+ libpq
#   share/postgresql/   initdb 所需 bki/timezone/sql
# rpath：bin/* → @loader_path/../lib + ../lib/postgresql；lib/** → @loader_path(+/.. +/postgresql)
# 幂等：先清目标目录再生成。产物不入库（见 .gitignore），CI 由对象存储或本脚本现场生成。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

ARCH="$(uname -m)"
case "$ARCH" in
  arm64)  PLATFORM="macos-arm64" ;;
  x86_64) PLATFORM="macos-x64" ;;
  *) echo "[relocate] 不支持的架构：$ARCH" >&2; exit 1 ;;
esac

SRC="${1:-$(brew --prefix postgresql@17 2>/dev/null || echo /opt/homebrew/opt/postgresql@17)}"
DEST="${2:-$REPO_ROOT/macos/Runner/Resources/pg/$PLATFORM}"

if [[ ! -x "$SRC/bin/postgres" ]]; then
  echo "[relocate] 源 PG 不存在：$SRC/bin/postgres" >&2
  echo "           先 brew install postgresql@17，或把源目录作为第一个参数传入。" >&2
  exit 1
fi

EXPECT_VER="$(tr -d '[:space:]' < "$REPO_ROOT/scripts/pg/pg-version.txt" 2>/dev/null || true)"
FOUND_VER="$("$SRC/bin/postgres" --version | grep -oE '[0-9]+\.[0-9]+' | head -1)"
echo "[relocate] 源=$SRC (PG $FOUND_VER)  目标=$DEST  期望主版本≈$EXPECT_VER"

echo "[relocate] 清理并创建目标目录"
rm -rf "$DEST"
mkdir -p "$DEST/bin" "$DEST/lib" "$DEST/share"

echo "[relocate] 拷贝 bin / lib/postgresql / share/postgresql"
cp -RL "$SRC/bin/." "$DEST/bin/"
cp -RL "$SRC/lib/postgresql" "$DEST/lib/postgresql"
# 删除运行期不需要的构建/测试产物（pgxs 扩展构建系统、回归测试二进制）：瘦身 + 去绝对依赖
rm -rf "$DEST/lib/postgresql/pgxs"
# 仅拷 initdb/运行所需的 share/postgresql（排除 doc/man/locale 以瘦身）
cp -RL "$SRC/share/postgresql" "$DEST/share/postgresql"

is_macho() { file -b "$1" 2>/dev/null | grep -qiE "mach-o"; }
all_deps() { otool -L "$1" 2>/dev/null | tail -n +2 | awk '{print $1}'; }
VENDOR_DIR="$DEST/lib"

# 把一条依赖引用解析为「绝对源路径」；refdir = 引用方源文件目录（解析 @loader_path/@rpath）
resolve_dep() {
  local ref="$1" refdir="$2" base
  case "$ref" in
    /opt/homebrew/*|/usr/local/*) [[ -f "$ref" ]] && echo "$ref" ;;
    @loader_path/*) base="${ref#@loader_path/}"; [[ -f "$refdir/$base" ]] && echo "$refdir/$base" ;;
    @rpath/*)       base="${ref#@rpath/}";       [[ -f "$refdir/$base" ]] && echo "$refdir/$base" ;;
    *) : ;;   # /usr/lib /System 系统库或裸名 → 忽略
  esac
}

pg_owns() { [[ -f "$DEST/lib/postgresql/$1" ]]; }     # PG 自带模块不外置到 lib/ flat

# ---- 递归求外部依赖闭包（绝对源路径），含 @loader_path 解析 ----------------
echo "[relocate] 计算外部依赖闭包"
SEEN="$(mktemp)"; trap 'rm -f "$SEEN"' EXIT
WORK=()
# 种子用「源」文件，便于按其原目录解析 @loader_path
while read -r f; do is_macho "$f" && WORK+=("$f"); done \
  < <(find "$SRC/bin" "$SRC/lib/postgresql" -type f 2>/dev/null)

idx=0
while (( idx < ${#WORK[@]} )); do
  cur="${WORK[$idx]}"; idx=$((idx+1))
  curdir="$(cd "$(dirname "$cur")" 2>/dev/null && pwd)" || continue
  while read -r ref; do
    [[ -z "$ref" ]] && continue
    abs="$(resolve_dep "$ref" "$curdir")"
    [[ -z "$abs" ]] && continue
    base="$(basename "$abs")"
    pg_owns "$base" && continue
    grep -qxF "$abs" "$SEEN" 2>/dev/null && continue
    echo "$abs" >> "$SEEN"
    [[ -f "$VENDOR_DIR/$base" ]] || { cp -L "$abs" "$VENDOR_DIR/$base"; chmod u+w "$VENDOR_DIR/$base"; }
    WORK+=("$abs")    # 继续解析该库自身依赖
  done < <(all_deps "$cur")
done
echo "[relocate] vendored 外部 dylib 数：$(find "$VENDOR_DIR" -maxdepth 1 -name '*.dylib' | wc -l | tr -d ' ')"

# ---- 改写 install name + id + rpath -------------------------------------
have_base() { [[ -f "$DEST/lib/$1" || -f "$DEST/lib/postgresql/$1" ]]; }

rewrite_macho() {
  local macho="$1" ref base
  chmod u+w "$macho"
  if [[ "$macho" == *.dylib || "$macho" == *.so ]]; then
    install_name_tool -id "@rpath/$(basename "$macho")" "$macho" 2>/dev/null || true
  fi
  while read -r ref; do
    [[ -z "$ref" ]] && continue
    case "$ref" in @rpath/*|/usr/lib/*|/System/*) continue ;; esac
    base="$(basename "$ref")"
    have_base "$base" || continue
    install_name_tool -change "$ref" "@rpath/$base" "$macho" 2>/dev/null || true
  done < <(all_deps "$macho")
}
add_rpath() { install_name_tool -add_rpath "$2" "$1" 2>/dev/null || true; }

echo "[relocate] 改写 bin/*"
while read -r f; do
  is_macho "$f" || continue
  rewrite_macho "$f"
  add_rpath "$f" "@loader_path/../lib"
  add_rpath "$f" "@loader_path/../lib/postgresql"
done < <(find "$DEST/bin" -type f)

echo "[relocate] 改写 lib/**（按内容判定 Mach-O）"
while read -r f; do
  is_macho "$f" || continue
  rewrite_macho "$f"
  add_rpath "$f" "@loader_path"
  add_rpath "$f" "@loader_path/.."
  add_rpath "$f" "@loader_path/postgresql"
done < <(find "$DEST/lib" -type f)

# ---- ad-hoc 重签名（install_name_tool 改写后原签名失效，Apple Silicon 会 SIGKILL）----
echo "[relocate] ad-hoc 重签名所有 Mach-O"
while read -r f; do
  is_macho "$f" || continue
  codesign --remove-signature "$f" 2>/dev/null || true
  codesign --force --sign - "$f" 2>/dev/null || { echo "  [sign-fail] $f" >&2; exit 1; }
done < <(find "$DEST/bin" "$DEST/lib" -type f)

# ---- 自洽性校验 ----------------------------------------------------------
echo "[relocate] 校验：不应再残留 /opt/homebrew | /usr/local 绝对依赖"
LEAK=0
while read -r f; do
  is_macho "$f" || continue
  if otool -L "$f" 2>/dev/null | tail -n +2 | grep -qE '/(opt/homebrew|usr/local)/'; then
    echo "  [leak] $f" >&2
    otool -L "$f" 2>/dev/null | grep -E '/(opt/homebrew|usr/local)/' >&2
    LEAK=1
  fi
done < <(find "$DEST/bin" "$DEST/lib" -type f)
(( LEAK )) && { echo "[relocate] 绝对路径依赖泄漏，重定位不完整" >&2; exit 1; }

DU="$(du -sh "$DEST" | awk '{print $1}')"
echo "[relocate] OK - 自洽 size=${DU} dest=${DEST}"
echo "[relocate] 自检 postgres --version:"
"$DEST/bin/postgres" --version
