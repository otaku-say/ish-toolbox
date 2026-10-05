#!/bin/sh
# doctor.sh —— 工具箱体检（只读）
#
# 三件事：
#   1. 完整性——比各架构的 SHA256SUMS
#   2. 免依赖——无 PT_INTERP + 无 NEEDED（静态链接）
#   3. 架构正确——读 ELF 头 e_machine（第 18 字节），不信文件名
#
# 用法：sh scripts/doctor.sh [arm64|amd64]   不带参数则体检本机架构
# 退出码：0=健康，1=有问题
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
  arm64|amd64) A="$1" ;;
  *) case "$(uname -m)" in
       aarch64|arm64) A=arm64 ;;
       x86_64|amd64)  A=amd64 ;;
       *) echo "✗ 不支持的架构：$(uname -m)"; exit 1 ;;
     esac ;;
esac
[ "$A" = arm64 ] && EM=b7 || EM=3e
D="$ROOT/tools/$A"

echo "=== 体检 $A（期望 e_machine=$EM）==="
[ -d "$D" ] || { echo "✗ 找不到 $D"; exit 1; }

if [ -f "$D/SHA256SUMS" ]; then
  if ( cd "$D" && sha256sum -c SHA256SUMS > /tmp/.dr.$$ 2>&1 ); then
    echo "  ✓ 完整性：全部哈希一致"
  else
    grep -v ': OK$' /tmp/.dr.$$ | sed 's/^/  ✗ /'
  fi
  rm -f /tmp/.dr.$$
else
  echo "  ⚠ 无 SHA256SUMS"
fi

echo
printf '  %-9s %-6s %-6s %s\n' 命令 静态 架构 大小
bad=0
for f in "$D"/*; do
  case "$(basename "$f")" in SHA256SUMS) continue ;; esac
  [ -f "$f" ] || continue
  n="$(basename "$f")"; [ "$n" = "SHA256SUMS" ] && continue

  st=FAIL
  readelf -l "$f" 2>/dev/null | grep -q INTERP || {
    readelf -d "$f" 2>/dev/null | grep -q NEEDED || st=OK
  }
  em=$(od -An -tx1 -j18 -N1 "$f" 2>/dev/null | tr -d ' \n')
  arch=$([ "$em" = "$EM" ] && echo ✓ || echo "✗$em")
  [ "$st" != OK ] && bad=$((bad+1))
  [ "$em" != "$EM" ] && bad=$((bad+1))
  printf '  %-9s %-6s %-6s %s\n' "$n" "$st" "$arch" \
    "$(awk -v s=$(wc -c < "$f") 'BEGIN{printf "%.1fMB", s/1048576}')"
done

echo
printf '  合计 %s MB\n' "$(ls -l "$D" | awk '!/SHA256/{t+=$5} END{printf "%.1f", t/1048576}')"
if [ "$bad" -eq 0 ]; then echo "✓ $A 健康"; exit 0; else echo "✗ $A 有 $bad 处问题"; exit 1; fi