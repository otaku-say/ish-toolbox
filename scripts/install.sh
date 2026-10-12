#!/bin/sh
# install.sh —— 把工具箱装到 PATH 里（按当前架构自动选）
#
# 用法：
#   sh install.sh                  # 装到 ~/.local/bin（默认，无需 root）
#   sh install.sh /usr/local/bin   # 装到指定目录（需要权限）
#
# 装完即可直接敲命令名。卸载：删掉目标目录下的同名文件即可。
#
# 说明（2026-10 AOJIT 迁移）：凡 AOJIT 提供加速的程序（busybox/python3/curl/
# openssl/ssh 全家/sqlite3/socat/drill）已从工具箱下架，改由系统 busybox 与
# apk 包提供（见 README “AOJIT 迁移说明”）。本脚本只安装仓库 tools/ 现存工具，
# 不再提供 --set-default-busybox（系统 busybox 即 AOJIT 全速版，无需替换）。
set -u

usage() {
  printf '用法：sh %s [目标目录]\n\n' "$0"
  printf '  （无选项）  校验并安装当前架构二进制到目标目录（默认 ~/.local/bin）\n'
  printf '  --help      显示本帮助\n'
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

DEST=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --set-default-busybox|--unset-default-busybox|--busybox-links-dir=*)
      printf '✗ 该选项已移除：工具箱不再自带 busybox（改用系统 AOJIT 加速版，见 README）\n' >&2
      exit 1 ;;
    --help|-h) usage; exit 0 ;;
    --*) printf '✗ 未知参数：%s（--help 查看用法）\n' "$1" >&2; exit 1 ;;
    *) [ -z "$DEST" ] || { printf '✗ 目标目录只能指定一次\n' >&2; exit 1; }; DEST="$1" ;;
  esac
  shift
done

case "$(uname -m)" in
  aarch64|arm64) ARCH=arm64; EM=b7 ;;
  x86_64|amd64)  ARCH=amd64; EM=3e ;;
  *) printf '✗ 不支持的架构：%s\n' "$(uname -m)" >&2; exit 1 ;;
esac
SRC="$ROOT/tools"

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v busybox >/dev/null 2>&1; then
    busybox sha256sum "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    printf '✗ 校验需要 sha256sum、BusyBox 或 openssl\n' >&2; return 1
  fi
}

# ── 常规安装：拷贝当前架构二进制到目标目录 ──────────────────────────
DEST="${DEST:-$HOME/.local/bin}"
mkdir -p "$DEST" || { printf '✗ 无法创建 %s\n' "$DEST" >&2; exit 1; }
echo "→ 架构 $ARCH，目标 $DEST"

ok=0; skip=0
for f in "$SRC"/*/"$ARCH"/*; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"

  # 架构校验：不信文件名，读 ELF 头第 18 字节
  em=$(od -An -tx1 -j18 -N1 "$f" 2>/dev/null | tr -d ' \n')
  [ "$em" = "$EM" ] || { echo "  ✗ $name 架构不符（$em ≠ $EM）"; skip=$((skip + 1)); continue; }

  cp -f "$f" "$DEST/$name" && chmod +x "$DEST/$name" \
    && { printf '  ✓ %-8s %s\n' "$name" "$(awk -v s=$(wc -c < "$DEST/$name") 'BEGIN{printf "%.1fMB", s/1048576}')"; ok=$((ok + 1)); }
done

echo
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo "⚠ $DEST 不在 PATH 中，加这一行到 ~/.ashrc："; echo "    PATH=\"\$PATH:$DEST\"" ;;
esac
echo "✓ 装好 $ok 个（$ARCH）${skip:+，跳过 $skip}"
