#!/usr/bin/env bash
# 本地覆盖率报告 —— 镜像 CI 的 very_good_coverage 门禁，可当 pre-push 闸用。
#
# 为什么需要：
#   - flutter test --coverage 写出的 coverage/lcov.info 是 Windows 反斜杠路径
#     （SF:lib\...），且不做任何排除，本地直接读数会偏低（~68.8%），误导。
#   - CI 用 VeryGoodOpenSource/very_good_coverage@v3 + 一份 exclude glob 排除清单，
#     口径才是真口径。本脚本把那份口径 1:1 搬到本地。
#
# 单一事实源：exclude 清单从 .github/workflows/ci.yml 的 `exclude:` 行
#   运行时抽取（见 CI_FILE / extract_exclude）——脚本不另存一份，杜绝漂移。
#   抽取失败则硬退出，绝不静默用过期口径。
#
# 口径对齐 very_good_coverage：line 覆盖率 = ΣLH / ΣLF（只统计未被排除的文件）。
#   阈值 70 与 ci.yml min_coverage 一致（见 ci.yml ~L80）。
#
# T5 手动回归说明：交互式 canvas painter（canvas_view / edge_painter /
#   canvas_screen / *_fab / *_toolbar）以及 media_kit 依赖件 headless 不可测，
#   走人工回归（docs/internal/t5-manual-regression.md）。CI exclude 已剔除
#   media_kit 件；painter 仍计入分母，是「测得到但故意低」的已知缺口，非隐藏。
#
# PG 说明：本地无 PG binary / TEST_PG_URL 未设 → storage/repositories/postgres_*
#   集成测试被 markTestSkipped，这些文件本地显示欠覆盖属正常。CI 起 postgres:17
#   service 真跑，CI-effective 实际更高。故本地数字是「保守下界」。
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

FLUTTER="${FLUTTER_BIN:-C:/Users/Kerro/flutter/bin/flutter.bat}"
CI_FILE=".github/workflows/ci.yml"
LCOV="coverage/lcov.info"
THRESHOLD=70

# ── 从 ci.yml 抽取 exclude 清单（单一事实源）─────────────────────────────
# 匹配形如:  exclude: 'glob1 glob2 ...'
extract_exclude() {
  grep -E "^[[:space:]]*exclude:[[:space:]]*'" "$CI_FILE" \
    | head -n1 \
    | sed -E "s/^[[:space:]]*exclude:[[:space:]]*'//; s/'[[:space:]]*$//"
}

EXCLUDE_GLOBS="$(extract_exclude)"
if [[ -z "${EXCLUDE_GLOBS// /}" ]]; then
  echo "FATAL: 无法从 $CI_FILE 抽取 exclude 清单（格式变了？）。拒绝用过期口径。" >&2
  exit 2
fi
echo "[exclude] 源自 $CI_FILE: $EXCLUDE_GLOBS"

# ── 运行全量测试 + 覆盖率 ────────────────────────────────────────────────
# ~600 测试，部分 skip；给足超时。SKIP_TEST=1 可跳过重跑、直接读现有 lcov。
# 记测试退出码但不立刻退出：即便有用例失败（如本地慢盘致 logger rotation 超时），
# lcov 仍已写出，覆盖率照常算；脚本最终退出码同时反映「测试是否全过」与「门禁」。
TEST_RC=0
if [[ "${SKIP_TEST:-0}" != "1" ]]; then
  echo "[test] $FLUTTER test --coverage（可能 20 分钟+）"
  "$FLUTTER" test --coverage || TEST_RC=$?
  if [[ "$TEST_RC" != "0" ]]; then
    echo "[test] 有用例失败（rc=$TEST_RC）——仍继续算覆盖率；脚本最终会非零退出。" >&2
  fi
fi

if [[ ! -f "$LCOV" ]]; then
  echo "FATAL: 找不到 $LCOV。" >&2
  exit 2
fi

# ── glob → 正则：把 ci.yml 的 shell-style glob 转成 awk 用的锚定正则 ──────
# 规则：. → \.   * → [^/]*（不跨目录）   ** → .*（跨目录，先于 * 处理）
glob_to_regex() {
  local g="$1" out="" i ch
  g="${g//./\\.}"
  g="${g//\*\*/$'\x01'}"   # ** 占位
  g="${g//\*/[^/]*}"       # 单 * 不跨目录
  g="${g//$'\x01'/.*}"     # 占位 → .*
  printf '%s' "^${g}$"
}

# 预编译排除正则，写进临时文件供 awk 读。
EXC_REGEX_FILE="$(mktemp)"
trap 'rm -f "$EXC_REGEX_FILE"' EXIT
for g in $EXCLUDE_GLOBS; do
  glob_to_regex "$g" >> "$EXC_REGEX_FILE"
  printf '\n' >> "$EXC_REGEX_FILE"
done

# ── 计算 CI-effective 覆盖率 ─────────────────────────────────────────────
# 归一化反斜杠 → 斜杠；逐文件判排除；只对未排除文件累加 LF/LH。
GATE_RC=0
awk -v thr="$THRESHOLD" -v excf="$EXC_REGEX_FILE" '
BEGIN {
  n = 0
  while ((getline line < excf) > 0) { if (line != "") exc[n++] = line }
}
function excluded(p,   i) {
  for (i = 0; i < n; i++) if (p ~ exc[i]) return 1
  return 0
}
/^SF:/ {
  sf = substr($0, 4)
  gsub(/\\/, "/", sf)
  skip = excluded(sf)
}
/^DA:/ {
  if (!skip) {
    split(substr($0, 4), a, ",")
    tot_lf++
    if (a[2] + 0 > 0) tot_lh++
  }
}
END {
  if (tot_lf == 0) { print "FATAL: 未统计到任何行（lcov 空？）"; exit 2 }
  pct = tot_lh * 100.0 / tot_lf
  printf "[coverage] CI-effective = %.2f%%  (hit %d / found %d, 已排除 CI exclude 清单)\n", pct, tot_lh, tot_lf
  if (pct + 1e-9 >= thr) {
    printf "[gate] PASS  (%.2f%% >= %d%%)\n", pct, thr
    exit 0
  } else {
    printf "[gate] FAIL  (%.2f%% < %d%%)\n", pct, thr
    exit 1
  }
}
' "$LCOV" || GATE_RC=$?

# 最终退出码：门禁 FAIL（rc=1/2）优先；否则若测试有失败则非零透出。
if [[ "$GATE_RC" != "0" ]]; then
  exit "$GATE_RC"
fi
if [[ "$TEST_RC" != "0" ]]; then
  echo "[result] 覆盖率门禁通过，但有测试失败（rc=$TEST_RC）——脚本非零退出。" >&2
  exit "$TEST_RC"
fi
exit 0
