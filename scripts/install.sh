#!/bin/sh
# install.sh —— 把工具箱装到 PATH 里（按当前架构自动选）
#
# 用法：
#   sh install.sh                 # 装到 ~/.local/bin（默认，无需 root）
#   sh install.sh /usr/local/bin  # 装到指定目录（需要权限）
#
# 装完即可直接敲命令名。卸载：删掉目标目录下的同名文件即可。
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$HOME/.local/bin}"

case "$(uname -m)" in
  aarch64|arm64) ARCH=arm64; EM=b7 ;;
  x86_64|amd64)  ARCH=amd64; EM=3e ;;
  *) echo "✗ 不支持的架构：$(uname -m)"; exit 1 ;;
esac
SRC="$ROOT/tools"
[ -d "$SRC" ] || { echo "✗ 找不到 $SRC"; exit 1; }

mkdir -p "$DEST" || { echo "✗ 无法创建 $DEST"; exit 1; }
echo "→ 架构 $ARCH，目标 $DEST"

ok=0; skip=0
for f in "$SRC"/*/"$ARCH"/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in SHA256SUMS) continue ;; esac
  name="$(basename "$f")"

  # 架构校验：不信文件名，读 ELF 头
  em=$(od -An -tx1 -j18 -N1 "$f" 2>/dev/null | tr -d ' \n')
  [ "$em" = "$EM" ] || { echo "  ✗ $name 架构不符（$em ≠ $EM）"; skip=$((skip+1)); continue; }

  cp -f "$f" "$DEST/$name" && chmod +x "$DEST/$name" \
    && { printf '  ✓ %-8s %s\n' "$name" "$(awk -v s=$(wc -c < "$DEST/$name") 'BEGIN{printf "%.1fMB", s/1048576}')"; ok=$((ok+1)); }
done

echo
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo "⚠ $DEST 不在 PATH 中，加这一行到 ~/.ashrc："; echo "    PATH=\"\$PATH:$DEST\"" ;;
esac
echo "✓ 装好 $ok 个（$ARCH）${skip:+，跳过 $skip}"
