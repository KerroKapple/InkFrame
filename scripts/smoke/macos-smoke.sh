#!/usr/bin/env bash
# macOS 烟测 —— 复现 .github/workflows/smoke.yml 的 macOS 路径，可本地一键跑。
#   完整模式（默认）：pub get → analyze → test(--exclude-tags pg) → build macos → boot 检查
#   --boot-only     ：仅对已构建的 .app 做 boot 检查（CI 在 build step 之后调用本脚本）
#
# Flutter 不在 PATH 时显式指定：
#   FLUTTER=/path/to/flutter bash scripts/smoke/macos-smoke.sh
# boot 检查等待秒数可调：BOOT_WAIT=20 bash scripts/smoke/macos-smoke.sh
#
# 设计：嵌入式 PG 不在启动关键路径（见 lib/main.dart），故 boot 检查不依赖 PG 二进制；
# 排除 pg（@Tags(['pg'])，无 TEST_PG_URL 时本就 markTestSkipped）与 golden（像素基线锁
# canonical ubuntu，mac/win 字体光栅化差异会 false-fail）两类，与 smoke.yml 一致。
set -euo pipefail
cd "$(cd "$(dirname "$0")/../.." && pwd)"

FLUTTER="${FLUTTER:-flutter}"
BOOT_ONLY=0
[[ "${1:-}" == "--boot-only" ]] && BOOT_ONLY=1

if [[ "$BOOT_ONLY" -eq 0 ]]; then
  echo "→ flutter pub get";          "$FLUTTER" pub get
  echo "→ flutter analyze";          "$FLUTTER" analyze
  echo "→ flutter test (no pg/golden)"; "$FLUTTER" test --exclude-tags "pg || golden"
  echo "→ flutter build macos";      "$FLUTTER" build macos --release
fi

APP="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' 2>/dev/null | head -1)"
if [[ -z "$APP" ]]; then
  echo "[smoke] 找不到 .app —— 先构建（去掉 --boot-only）" >&2
  exit 1
fi
BIN="$APP/Contents/MacOS/$(basename "$APP" .app)"
[[ -x "$BIN" ]] || BIN="$(find "$APP/Contents/MacOS" -maxdepth 1 -type f -perm -u+x 2>/dev/null | head -1)"
if [[ -z "$BIN" || ! -x "$BIN" ]]; then
  echo "[smoke] .app 内找不到可执行文件：$APP" >&2
  exit 1
fi

WAIT="${BOOT_WAIT:-12}"
LOG="$(mktemp -t inkframe-smoke.XXXXXX.log)"
echo "→ boot 检查：$BIN（存活 ${WAIT}s 视为启动未崩溃；日志 $LOG）"
"$BIN" >"$LOG" 2>&1 &
PID=$!

ALIVE=1
for ((i=0; i<WAIT; i++)); do
  if ! kill -0 "$PID" 2>/dev/null; then ALIVE=0; break; fi
  sleep 1
done

if [[ "$ALIVE" -eq 0 ]]; then
  CODE=0; wait "$PID" || CODE=$?
  echo "[smoke] 进程提前退出 code=$CODE —— 启动崩溃" >&2
  sed -n '1,40p' "$LOG" >&2 || true
  exit 1
fi

echo "[smoke] 进程存活 ${WAIT}s，启动未崩溃 ✅"
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
echo "[smoke] OK"
