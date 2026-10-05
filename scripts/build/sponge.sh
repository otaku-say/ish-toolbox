#!/bin/bash
# sponge.sh —— sponge（C；moreutils，自编译）
#
# 用途：管道落盘——先把 stdin 读完再写目标文件，避免“读-写同一文件”竞态。
# moreutils 官方无 GitHub Release，源取自 Debian pool 的 orig tarball。
# 注意：sponge.c 会 #include "physmem.c"（同目录兄弟文件），必须整包同目录编译。
. "$(dirname "$0")/_common.sh"

U=$(curl -fsSL --max-time 30 'https://deb.debian.org/debian/pool/main/m/moreutils/' 2>/dev/null \
    | grep -o 'moreutils_[0-9.]*\.orig\.tar\.[a-z]*' | sort -uV | tail -1)
[ -z "$U" ] && { echo "  ! sponge 源查询失败"; exit 0; }
echo "  sponge 上游: $U"

SRC=""
for d in /tmp/build/moreutils-*; do [ -f "$d/sponge.c" ] && SRC="$d"; done
if [ -z "$SRC" ]; then
  mkdir -p /tmp/build
  curl -fsSL --max-time 120 "https://deb.debian.org/debian/pool/main/m/moreutils/$U" -o /tmp/build/sponge.src 2>/dev/null \
    && tar xJf /tmp/build/sponge.src -C /tmp/build 2>/dev/null || true
  for d in /tmp/build/moreutils-*; do [ -f "$d/sponge.c" ] && SRC="$d"; done
fi
[ -n "$SRC" ] || { echo "  ✗ sponge.c 未找到（下载/解包失败）"; exit 0; }

"$CROSS_CC" $CSIZE -I"$SRC" "$SRC/sponge.c" -o /tmp/build/sponge.bin $CLINK \
  && install_verified /tmp/build/sponge.bin sponge \
  || echo "  ✗ sponge 编译失败"
