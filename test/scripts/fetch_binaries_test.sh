#!/usr/bin/env bash
# fetch-binaries.sh 回归测试（PKG-2A）。沙箱内跑：把脚本拷进临时仓库骨架，
# curl/brew 走 PATH stub，make-relocatable 用沙箱 stub —— 不碰真网络、不碰真仓库。
set -euo pipefail

REAL_SCRIPT="$(cd "$(dirname "$0")" && pwd)/../../scripts/pg/fetch-binaries.sh"
FIXTURES="$(cd "$(dirname "$0")" && pwd)/fixtures"
FAILURES=0

pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; FAILURES=$((FAILURES + 1)); }

# GNU/BSD 双轨（macOS 无 sha256sum）
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

FIXTURE_ZIP="$FIXTURES/fake-edb-pgsql.zip"
FIXTURE_ZIP_MISSING_TOOL="$FIXTURES/fake-edb-missing-pg-restore.zip"
FIXTURE_SHA="$(sha256_of "$FIXTURE_ZIP")"
FIXTURE_MISSING_SHA="$(sha256_of "$FIXTURE_ZIP_MISSING_TOOL")"

# 沙箱 = 迷你仓库骨架：scripts/pg/{fetch-binaries.sh,pg-version.txt,upstream.lock} + PATH stub 目录
setup_sandbox() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/scripts/pg" "$dir/bin"
  cp "$REAL_SCRIPT" "$dir/scripts/pg/fetch-binaries.sh"
  echo "17.2" > "$dir/scripts/pg/pg-version.txt"
  cat > "$dir/scripts/pg/upstream.lock" <<EOF
WINDOWS_X64_URL=https://example.test/postgresql-17.2-3-windows-x64-binaries.zip
WINDOWS_X64_SHA256=$FIXTURE_SHA
EOF
  # curl stub：记录 URL 到 CURL_LOG，把 CURL_SERVE 指定的文件拷到 -o 目标；
  # CURL_SERVE_DIR 模式按 basename 提供（bucket 模式要拉 tar.gz + .sha256 两个文件）
  cat > "$dir/bin/curl" <<'CURL'
#!/usr/bin/env bash
out=""; url=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    -o) out="${args[$((i+1))]}" ;;
    http*) url="${args[$i]}" ;;
  esac
done
echo "$url" >> "${CURL_LOG:?}"
if [[ -n "${CURL_SERVE:-}" && -f "${CURL_SERVE}" ]]; then
  cp "$CURL_SERVE" "$out"; exit 0
fi
if [[ -n "${CURL_SERVE_DIR:-}" ]]; then
  base="$(basename "$url")"
  [[ -f "$CURL_SERVE_DIR/$base" ]] && { cp "$CURL_SERVE_DIR/$base" "$out"; exit 0; }
fi
exit 22
CURL
  chmod +x "$dir/bin/curl"
  echo "$dir"
}

# 在沙箱内跑脚本：$1=沙箱 $2=平台，其余透传环境（VAR=x 形式）
run_fetch() {
  local dir="$1" platform="$2"; shift 2
  ( cd "$dir" && PATH="$dir/bin:$PATH" INKFRAME_PG_PLATFORM="$platform" env "$@" bash scripts/pg/fetch-binaries.sh )
}

WIN_TARGET="windows/runner/resources/pg/windows-x64"
MAC_TARGET="macos/Runner/Resources/pg/macos-arm64"

# --- Task 1: upstream windows-x64 happy path -------------------------------
echo "=== Task 1: upstream windows happy path ==="
SB="$(setup_sandbox)"
export CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
set +e
CURL_SERVE="$FIXTURE_ZIP" run_fetch "$SB" windows-x64 CURL_LOG="$CURL_LOG" CURL_SERVE="$FIXTURE_ZIP" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 0 ]] && pass "exit 0" || fail "exit $ec (want 0)"
[[ -d "$SB/$WIN_TARGET/bin" && -d "$SB/$WIN_TARGET/lib" && -d "$SB/$WIN_TARGET/share" ]] \
  && pass "bin/lib/share 落位" || fail "bin/lib/share 缺失"
missing=0
for t in postgres initdb pg_ctl pg_dump pg_restore; do
  [[ -f "$SB/$WIN_TARGET/bin/$t.exe" ]] || { fail "缺 $t.exe"; missing=1; }
done
[[ $missing -eq 0 ]] && pass "必需工具齐全（postgres/initdb/pg_ctl/pg_dump/pg_restore）"
[[ ! -e "$SB/$WIN_TARGET/share/doc" && ! -e "$SB/$WIN_TARGET/share/man" && ! -e "$SB/$WIN_TARGET/share/locale" ]] \
  && pass "share/doc|man|locale 已裁剪" || fail "share 未裁剪"
[[ ! -e "$SB/$WIN_TARGET/lib/libpq.lib" ]] && pass "lib/*.lib 已裁剪" || fail "lib/*.lib 未裁剪"
[[ -z "$(ls "$SB/$WIN_TARGET/bin/" | grep '^wx')" ]] && pass "bin/wx*.dll 已裁剪" || fail "bin/wx*.dll 未裁剪"
[[ -f "$SB/$WIN_TARGET/lib/libpq.dll" ]] && pass "运行期 dll 保留" || fail "运行期 dll 被误删"
[[ ! -e "$SB/$WIN_TARGET/pgAdmin 4" && ! -e "$SB/$WIN_TARGET/include" && ! -e "$SB/$WIN_TARGET/StackBuilder" ]] \
  && pass "pgAdmin/StackBuilder/include 未拷入" || fail "多拷了 EDB 附属目录"
[[ ! -e "$SB/$WIN_TARGET.partial" ]] && pass "无 .partial 残留" || fail ".partial 残留"
grep -q "example.test/postgresql-17.2-3" "$CURL_LOG" && pass "按 lock URL 下载" || fail "未按 lock URL 下载"
[[ "$(wc -l < "$CURL_LOG")" -eq 1 ]] && pass "upstream 模式只下载 1 个文件" || fail "下载次数异常"

# --- Task 2: 幂等重跑不再下载 ----------------------------------------------
echo "=== Task 2: idempotent rerun ==="
set +e
run_fetch "$SB" windows-x64 CURL_LOG="$CURL_LOG" CURL_SERVE="$FIXTURE_ZIP" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 0 ]] && pass "重跑 exit 0" || fail "重跑 exit $ec"
[[ "$(wc -l < "$CURL_LOG")" -eq 1 ]] && pass "重跑零下载（已就绪短路）" || fail "重跑触发了下载"
rm -rf "$SB"

# --- Task 3: SHA256 不匹配 → 失败且零残留 ----------------------------------
echo "=== Task 3: sha mismatch ==="
SB="$(setup_sandbox)"
CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
sed -i.bak "s/^WINDOWS_X64_SHA256=.*/WINDOWS_X64_SHA256=$(printf 'deadbeef%.0s' 1 2 3 4 5 6 7 8)/" "$SB/scripts/pg/upstream.lock"
set +e
run_fetch "$SB" windows-x64 CURL_LOG="$CURL_LOG" CURL_SERVE="$FIXTURE_ZIP" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -ne 0 ]] && pass "sha 不匹配 → 非零退出" || fail "sha 不匹配竟然成功"
[[ ! -e "$SB/$WIN_TARGET" && ! -e "$SB/$WIN_TARGET.partial" ]] && pass "失败零残留" || fail "失败留下残留目录"
rm -rf "$SB"

# --- Task 4: 缺必需工具（无 pg_restore）→ 失败且零残留 ----------------------
echo "=== Task 4: missing required tool ==="
SB="$(setup_sandbox)"
CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
sed -i.bak "s/^WINDOWS_X64_SHA256=.*/WINDOWS_X64_SHA256=$FIXTURE_MISSING_SHA/" "$SB/scripts/pg/upstream.lock"
set +e
run_fetch "$SB" windows-x64 CURL_LOG="$CURL_LOG" CURL_SERVE="$FIXTURE_ZIP_MISSING_TOOL" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -ne 0 ]] && pass "缺 pg_restore → 非零退出" || fail "缺工具竟然成功"
[[ ! -e "$SB/$WIN_TARGET" && ! -e "$SB/$WIN_TARGET.partial" ]] && pass "失败零残留" || fail "失败留下残留目录"
rm -rf "$SB"

# --- Task 5: lock 缺键 → 失败 ----------------------------------------------
echo "=== Task 5: lock missing key ==="
SB="$(setup_sandbox)"
CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
grep -v '^WINDOWS_X64_SHA256=' "$SB/scripts/pg/upstream.lock" > "$SB/scripts/pg/upstream.lock.tmp"
mv "$SB/scripts/pg/upstream.lock.tmp" "$SB/scripts/pg/upstream.lock"
set +e
out="$(run_fetch "$SB" windows-x64 CURL_LOG="$CURL_LOG" CURL_SERVE="$FIXTURE_ZIP" 2>&1)"
ec=$?
set -e
[[ $ec -ne 0 ]] && pass "lock 缺 SHA 键 → 非零退出" || fail "lock 缺键竟然成功"
echo "$out" | grep -qi "WINDOWS_X64_SHA256" && pass "报错点名缺失键" || fail "报错未点名缺失键"
rm -rf "$SB"

# --- Task 6: bucket 模式（PG_ARTIFACT_BASE_URL）优先且语义不变 --------------
echo "=== Task 6: bucket mode override ==="
SB="$(setup_sandbox)"
CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
# 运行时造 bucket tar.gz：内容布局 = <root>/{bin,lib,share}（strip-components=1 语义）
BUCKET_DIR="$SB/bucketsrv"
mkdir -p "$BUCKET_DIR/stage/pg/bin" "$BUCKET_DIR/stage/pg/lib" "$BUCKET_DIR/stage/pg/share"
printf '#!/usr/bin/env bash\necho "postgres (PostgreSQL) 17.2"\n' > "$BUCKET_DIR/stage/pg/bin/postgres.exe"
for t in initdb pg_ctl pg_dump pg_restore; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$BUCKET_DIR/stage/pg/bin/$t.exe"
done
chmod +x "$BUCKET_DIR/stage/pg/bin/"*.exe
echo lib > "$BUCKET_DIR/stage/pg/lib/libpq.dll"
echo bki > "$BUCKET_DIR/stage/pg/share/postgres.bki"
tar -czf "$BUCKET_DIR/windows-x64.tar.gz" -C "$BUCKET_DIR/stage" pg
sha256_of "$BUCKET_DIR/windows-x64.tar.gz" > "$BUCKET_DIR/windows-x64.tar.gz.sha256"
set +e
run_fetch "$SB" windows-x64 CURL_LOG="$CURL_LOG" CURL_SERVE_DIR="$BUCKET_DIR" \
  PG_ARTIFACT_BASE_URL="https://bucket.test/inkframe/pg" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 0 ]] && pass "bucket 模式 exit 0" || fail "bucket 模式 exit $ec"
grep -q "bucket.test/inkframe/pg/17.2/windows-x64.tar.gz" "$CURL_LOG" \
  && pass "走对象存储 URL（模式优先级正确）" || fail "未走对象存储 URL"
[[ "$(wc -l < "$CURL_LOG")" -eq 2 ]] && pass "bucket 模式下载 tar.gz + .sha256 两件" || fail "bucket 下载次数异常"
[[ -f "$SB/$WIN_TARGET/bin/postgres.exe" ]] && pass "bucket 落位" || fail "bucket 未落位"
rm -rf "$SB"

# --- Task 7: linux-x64 upstream 不支持 -------------------------------------
echo "=== Task 7: linux upstream unsupported ==="
SB="$(setup_sandbox)"
CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
set +e
out="$(run_fetch "$SB" linux-x64 CURL_LOG="$CURL_LOG" 2>&1)"
ec=$?
set -e
[[ $ec -ne 0 ]] && pass "linux upstream → 非零退出" || fail "linux upstream 竟然成功"
echo "$out" | grep -q "PG_ARTIFACT_BASE_URL" && pass "报错指路（系统 PG / 对象存储）" || fail "报错未指路"
rm -rf "$SB"

# --- Task 8: macOS upstream 委托 make-relocatable + 主版本匹配 --------------
echo "=== Task 8: macOS upstream (brew + relocate stub) ==="
setup_mac_sandbox() {
  local dir="$1" brew_ver="$2"
  # brew stub
  cat > "$dir/bin/brew" <<'BREW'
#!/usr/bin/env bash
if [[ "${1:-}" == "--prefix" ]]; then echo "${FAKE_BREW_PREFIX:?}"; exit 0; fi
exit 1
BREW
  chmod +x "$dir/bin/brew"
  # 假 brew keg
  mkdir -p "$dir/fakebrew/bin"
  printf '#!/usr/bin/env bash\necho "postgres (PostgreSQL) %s"\n' "$brew_ver" > "$dir/fakebrew/bin/postgres"
  chmod +x "$dir/fakebrew/bin/postgres"
  # make-relocatable stub：记录参数，产出含全部必需工具的 DEST
  cat > "$dir/scripts/pg/make-relocatable-macos.sh" <<'REL'
#!/usr/bin/env bash
set -euo pipefail
echo "relocate $*" >> "${REL_LOG:?}"
SRC="$1"; DEST="$2"
rm -rf "$DEST"
mkdir -p "$DEST/bin" "$DEST/lib" "$DEST/share/postgresql"
for t in postgres initdb pg_ctl pg_dump pg_restore; do
  cp "$SRC/bin/postgres" "$DEST/bin/$t"
  chmod +x "$DEST/bin/$t"
done
REL
  chmod +x "$dir/scripts/pg/make-relocatable-macos.sh"
}

# 8a: brew 17.6（补丁位浮动）→ 主版本 17 匹配 → 成功
SB="$(setup_sandbox)"
CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
REL_LOG="$SB/rel.log"; : > "$REL_LOG"
setup_mac_sandbox "$SB" "17.6"
set +e
run_fetch "$SB" macos-arm64 CURL_LOG="$CURL_LOG" REL_LOG="$REL_LOG" FAKE_BREW_PREFIX="$SB/fakebrew" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 0 ]] && pass "brew 17.6 → 主版本匹配 exit 0" || fail "brew 17.6 exit $ec"
grep -q "relocate $SB/fakebrew" "$REL_LOG" && pass "以 brew prefix 为源委托 relocate" || fail "relocate 源参数错误"
[[ -f "$SB/$MAC_TARGET/bin/postgres" && -f "$SB/$MAC_TARGET/bin/pg_restore" ]] \
  && pass "macOS 落位含必需工具" || fail "macOS 未落位"
[[ ! -e "$SB/$MAC_TARGET.partial" ]] && pass "无 .partial 残留" || fail ".partial 残留"
[[ "$(wc -l < "$CURL_LOG")" -eq 0 ]] && pass "macOS upstream 零网络下载" || fail "macOS upstream 触发下载"
rm -rf "$SB"

# 8b: brew 18.0 → 主版本不匹配 → 失败且零残留
SB="$(setup_sandbox)"
CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
REL_LOG="$SB/rel.log"; : > "$REL_LOG"
setup_mac_sandbox "$SB" "18.0"
set +e
run_fetch "$SB" macos-arm64 CURL_LOG="$CURL_LOG" REL_LOG="$REL_LOG" FAKE_BREW_PREFIX="$SB/fakebrew" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -ne 0 ]] && pass "brew 18.0 → 主版本不匹配非零退出" || fail "18.0 竟然成功"
[[ ! -e "$SB/$MAC_TARGET" && ! -e "$SB/$MAC_TARGET.partial" ]] && pass "失败零残留" || fail "失败留下残留目录"
rm -rf "$SB"

# 8c: 无 brew → 明确报错指路
SB="$(setup_sandbox)"
CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
set +e
out="$(run_fetch "$SB" macos-arm64 CURL_LOG="$CURL_LOG" 2>&1)"
ec=$?
set -e
[[ $ec -ne 0 ]] && pass "无 brew keg → 非零退出" || fail "无 brew 竟然成功"
echo "$out" | grep -q "postgresql@17" && pass "报错指路 brew install postgresql@17" || fail "报错未指路"
rm -rf "$SB"

# --- Task 9: 坏现存树触发重建 + 陈旧 .partial 清理 ---------------------------
echo "=== Task 9: rebuild on corrupt tree + stale .partial cleanup ==="
SB="$(setup_sandbox)"
CURL_LOG="$SB/curl.log"; : > "$CURL_LOG"
set +e
run_fetch "$SB" windows-x64 CURL_LOG="$CURL_LOG" CURL_SERVE="$FIXTURE_ZIP" >/dev/null 2>&1
set -e
# 破坏现存树（删 share——残缺树不得骗过幂等短路）+ 制造上次被杀的陈旧 .partial
rm -rf "$SB/$WIN_TARGET/share"
mkdir -p "$SB/$WIN_TARGET.partial/junk"
set +e
run_fetch "$SB" windows-x64 CURL_LOG="$CURL_LOG" CURL_SERVE="$FIXTURE_ZIP" >/dev/null 2>&1
ec=$?
set -e
[[ $ec -eq 0 ]] && pass "坏树重跑 exit 0" || fail "坏树重跑 exit $ec"
[[ "$(wc -l < "$CURL_LOG")" -eq 2 ]] && pass "残缺树未短路,触发重新下载" || fail "残缺树被幂等短路放过"
[[ -d "$SB/$WIN_TARGET/share" ]] && pass "share 已随重建恢复" || fail "share 未恢复"
[[ ! -e "$SB/$WIN_TARGET.partial" ]] && pass "陈旧 .partial 已清理" || fail "陈旧 .partial 残留"
rm -rf "$SB"

echo ""
exit $FAILURES
