#!/usr/bin/env bash
# check-updated-at.sh
# PRD §21 硬规则：所有 UPDATE <table> SET 语句必须同时 SET updated_at（应用层维护，非 DB trigger）。
# 扫描 lib/storage/ 下的 .dart 文件，拦截缺失 updated_at 的 UPDATE 语句。
# 白名单：
#   - edges / jobs / batch_results 表 DDL 未含 updated_at 列，豁免
#   - migrations/*.sql 的 INSERT ON CONFLICT DO UPDATE 语句豁免
#   - 测试文件与生成文件豁免
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

FILE="${1:-}"
# 支持两种模式：单文件模式（pre-commit 传文件）和全量扫描（CI）
if [[ -n "$FILE" ]]; then
  TARGETS=("$FILE")
else
  # 全量扫描 lib/storage 目录
  while IFS= read -r -d '' f; do TARGETS+=("$f"); done < \
    <(find "$REPO_ROOT/lib/storage" -type f -name "*.dart" -print0 2>/dev/null)
fi

TABLES_WITHOUT_UPDATED_AT_REGEX='UPDATE\s+(edges|jobs|batch_results)\b'

VIOLATIONS=()
for f in "${TARGETS[@]:-}"; do
  [[ -z "$f" ]] && continue
  [[ "$f" != *.dart ]] && continue
  [[ "$f" == *_test.dart ]] && continue
  [[ "$f" == *.g.dart ]] && continue
  [[ "$f" == *.freezed.dart ]] && continue
  [[ "$f" != *"/lib/storage/"* && "$f" != *"lib/storage/"* ]] && continue

  # 找所有包含 "UPDATE " 的行（去掉注释行），然后判定：
  #   - 若匹配 TABLES_WITHOUT_UPDATED_AT_REGEX，跳过
  #   - 否则必须在同一个字符串拼接/语句内包含 "updated_at"
  # 实现：把 dart 源码里的多行字符串按 UPDATE 切片，每个语句段检查。
  python3 - "$f" "$TABLES_WITHOUT_UPDATED_AT_REGEX" <<'PY' || VIOLATIONS+=("$f")
import re, sys
path, excl = sys.argv[1], sys.argv[2]
src = open(path, encoding='utf-8').read()
# 只匹配独立的 UPDATE 语句（非 ON CONFLICT DO UPDATE 子句）。
# 判别：UPDATE 前面 80 字符内不能出现 "ON CONFLICT" / "DO UPDATE"。
pattern = re.compile(r"UPDATE\s+([A-Za-z_][A-Za-z0-9_]*)\s+SET", re.IGNORECASE)
excluded_tables = set("edges jobs batch_results schema_version".split())
excluded = re.compile(excl, re.IGNORECASE)
violations = []
for m in pattern.finditer(src):
    table = m.group(1).lower()
    start = m.start()
    prev = src[max(0, start-80):start]
    if re.search(r"ON\s+CONFLICT|DO\s+UPDATE", prev, re.IGNORECASE):
        continue
    if table in excluded_tables:
        continue
    # 对剩余窗口 400 字符检查 updated_at
    window = src[start:start+400]
    if 'updated_at' not in window:
        line_no = src[:start].count('\n') + 1
        violations.append((line_no, table, window.splitlines()[0][:120]))
if violations:
    print(f"[check-updated-at] {path}")
    for ln, tb, excerpt in violations:
        print(f"  L{ln} UPDATE {tb} 缺少 updated_at 维护：{excerpt}")
    sys.exit(1)
sys.exit(0)
PY
done

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  echo ""
  echo "🚫 [check-updated-at] 违规文件列出如上，请在 UPDATE 语句内显式 SET updated_at = @...；"
  echo "   推荐通过 BaseRepository.buildUpdate / withUpdatedAt 统一维护。"
  exit 1
fi

echo "[check-updated-at] OK"
exit 0
