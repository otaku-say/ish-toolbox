#!/bin/bash
# gen-doc-sums.sh —— 生成 tools/DOCS.sha256（每个工具的 USAGE.md 清单）
#
# 为什么需要它：二进制走 tools/SHA256SUMS.<arch>，使用说明走 tools/DOCS.sha256。
# 本地技能用 install.sh --update 同时拉这两份清单，保证 Agent 拿到的
# 「二进制 + 该二进制的使用说明」永远同版本。
#
# 同时做完整性门禁：**每个工具目录都必须有 USAGE.md**，缺一个就 exit 1。
# 用法：bash scripts/gen-doc-sums.sh    （在仓库根目录或任意位置均可）
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/tools" || { echo "✗ 找不到 tools/"; exit 1; }

# 1) 门禁：工具目录（含 arm64/ 或 amd64/ 子目录的）必须有 USAGE.md
miss=0; ntools=0
for d in */; do
  t="${d%/}"
  [ -d "$t/arm64" ] || [ -d "$t/amd64" ] || continue   # 非工具目录，跳过
  ntools=$((ntools+1))
  if [ ! -f "$t/USAGE.md" ]; then
    echo "  ✗ $t 缺 USAGE.md"
    miss=$((miss+1))
  fi
done

# 2) 生成清单（路径相对 tools/，与二进制清单同一坐标系）
find . -mindepth 2 -maxdepth 2 -name 'USAGE.md' -type f | sed 's|^\./||' | sort \
  | xargs -r sha256sum > DOCS.sha256

echo "✓ tools/DOCS.sha256 已生成：$(wc -l < DOCS.sha256) 份文档 / $ntools 个工具"
if [ "$miss" -gt 0 ]; then
  echo "✗ 有 $miss 个工具缺使用说明（每个工具目录都要有 USAGE.md）"
  exit 1
fi
exit 0
