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
D="$ROOT/tools"

echo "=== 体检 $A（期望 e_machine=$EM）==="
[ -d "$D" ] || { echo "✗ 找不到 $D"; exit 1; }

if [ -f "$D/SHA256SUMS.$A" ]; then
  if ( cd "$D" && sha256sum -c "SHA256SUMS.$A" > /tmp/.dr.$$ 2>&1 ); then
    echo "  ✓ 完整性：全部哈希一致"
  else
    grep -v ': OK$' /tmp/.dr.$$ | sed 's/^/  ✗ /'
  fi
  rm -f /tmp/.dr.$$
else
  echo "  ⚠ 无 SHA256SUMS.$A"
fi

echo
printf '  %-12s %-6s %-6s %s\n' 工具 静态 架构 大小
bad=0
for d in "$D"/*/"$A"/; do
  [ -d "$d" ] || continue
  n="$(basename "$(dirname "$d")")"; b="$d$n"
  if [ ! -f "$b" ]; then echo "  ✗ $n/ 缺 $A 主程序（期望 $n/$A/$n）"; bad=$((bad+1)); continue; fi
  st=FAIL
  readelf -l "$b" 2>/dev/null | grep -q INTERP || {
    readelf -d "$b" 2>/dev/null | grep -q NEEDED || st=OK
  }
  em=$(od -An -tx1 -j18 -N1 "$b" 2>/dev/null | tr -d ' \n')
  arch=$([ "$em" = "$EM" ] && echo ✓ || echo "✗$em")
  [ "$st" != OK ] && bad=$((bad+1))
  [ "$em" != "$EM" ] && bad=$((bad+1))
  af=$(find "$d" -type f ! -name "$n" | wc -l)
  printf '  %-12s %-6s %-6s %s%s\n' "$n" "$st" "$arch" \
    "$(awk -v s=$(wc -c < "$b") 'BEGIN{printf "%.1fMB", s/1048576}')" \
    "$([ "$af" -gt 0 ] && printf '（%s 个附属文件）' "$af")"
done
# 旧布局残留检查：顶层只允许「工具目录」与两个清单文件；
# arm64/amd64 目录、任何散文件 = 旧布局残留
for f in "$D"/*; do
  _n="$(basename "$f")"
  case "$_n" in
    "SHA256SUMS.$A"|"SHA256SUMS.arm64"|"SHA256SUMS.amd64") continue ;;
    "arm64"|"amd64")
      if [ "$_n" = "$A" ]; then
        echo "  ✗ 旧布局目录残留：$_n"; bad=$((bad+1))
      else
        echo "  ℹ 对侧架构旧目录（由对侧 job 清理）：$_n"
      fi
      continue ;;
  esac
  [ -d "$f" ] && continue
  echo "  ✗ 旧布局散文件残留：$_n"; bad=$((bad+1))
done

echo
printf '  合计 %s\n' "$(du -sh "$D" | cut -f1)"
if [ "$bad" -eq 0 ]; then echo "✓ $A 健康"; exit 0; else echo "✗ $A 有 $bad 处问题"; exit 1; fi