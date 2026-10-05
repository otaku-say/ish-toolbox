#!/bin/sh
# gen-table.sh —— 生成 README 的「上游版本 / 仓库版本 / 体积」对照表
#
# 数据源：
#   · 上游最新版本 —— GitHub API 实时查（每工具一次调用）
#   · 仓库当前版本 —— MANIFEST.tsv（由 sync-upstream.sh 写入）
#   · 体积         —— tools/{arm64,amd64}/ 实测
#
# 输出直接替换 README 里 <!-- TABLE:START --> … <!-- TABLE:END --> 之间的内容。
# 依赖：curl jq（CI 的 ubuntu-latest 自带）
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$ROOT/MANIFEST.tsv" ] || { echo "✗ 缺 MANIFEST.tsv"; exit 1; }
AUTH=""; [ -n "${GITHUB_TOKEN:-}" ] && AUTH="Authorization: Bearer ${GITHUB_TOKEN}"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT INT TERM

mb() { [ -f "$1" ] && awk -v s="$(wc -c < "$1")" 'BEGIN{printf "%.1f MB", s/1048576}' || echo "—"; }

{
  echo "| 工具 | 上游最新 | 仓库版本 | arm64 | amd64 | 状态 |"
  echo "|---|---|---|---|---|---|"
  # 跳过表头行，逐工具处理
  tail -n +2 "$ROOT/MANIFEST.tsv" | while IFS="$(printf '\t')" read -r cmd repo ver desc; do
    [ -z "${cmd:-}" ] && continue
    up=$(curl -fsSL --max-time 20 ${AUTH:+-H "$AUTH"} \
         "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | jq -r '.tag_name // "?"' 2>/dev/null)
    if [ "$up" = "$ver" ]; then mark="✅ 最新"; else mark="⬆ 待同步"; fi
    printf '| `%s` | %s | %s | %s | %s | %s |\n' \
      "$cmd" "$up" "$ver" "$(mb "$ROOT/tools/arm64/$cmd")" "$(mb "$ROOT/tools/amd64/$cmd")" "$mark"
  done
} > "$TMP"

# 总量行
{
  echo
  printf '共 %s 个工具 · arm64 合计 %s · amd64 合计 %s\n' \
    "$(tail -n +2 "$ROOT/MANIFEST.tsv" | wc -l)" \
    "$(ls -l "$ROOT/tools/arm64" 2>/dev/null | awk '!/SHA256/{t+=$5} END{printf "%.1f MB", t/1048576}')" \
    "$(ls -l "$ROOT/tools/amd64" 2>/dev/null | awk '!/SHA256/{t+=$5} END{printf "%.1f MB", t/1048576}')"
} >> "$TMP"

if grep -q 'TABLE:START' "$ROOT/README.md" 2>/dev/null; then
  # 用 awk 做标记间替换（不依赖 sed 的多行能力）
  awk -v tf="$TMP" '
    /<!-- TABLE:START -->/ { print; while ((getline line < tf) > 0) print line; skip=1; next }
    /<!-- TABLE:END -->/   { skip=0; print; next }
    skip != 1              { print }
  ' "$ROOT/README.md" > "$ROOT/README.md.new" && mv "$ROOT/README.md.new" "$ROOT/README.md"
  echo "✓ README 表格已更新（$(wc -l < "$TMP") 行）"
else
  echo "⚠ README 缺少 <!-- TABLE:START --> / <!-- TABLE:END --> 标记，未替换。表格内容如下："
  cat "$TMP"
fi