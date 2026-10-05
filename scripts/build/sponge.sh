#!/bin/bash
# sponge.sh —— sponge（C 单文件程序；moreutils，自编译）
#
# 用途：管道落盘——先把 stdin 读完再写目标文件，避免“读-写同一文件”竞态
# （典型：sed -i 不可用时的 `sed 's/x/y/' file > file`）。
# moreutils 官方无 GitHub Release，源取自 Debian pool 的 orig tarball；
# sponge.c 可独立编译、零依赖（沙箱实测：cc -Os -static sponge.c 直接通过）。
. "$(dirname "$0")/_common.sh"

U=$(curl -fsSL --max-time 30 'https://deb.debian.org/debian/pool/main/m/moreutils/' 2>/dev/null \
    | grep -o 'moreutils_[0-9.]*\.orig\.tar\.[a-z]*' | sort -uV | tail -1)
[ -z "$U" ] && { echo "  ! sponge 源查询失败"; exit 0; }
echo "  sponge 上游: $U"

D=/tmp/build/sponge-src
if [ ! -f "$D/sponge.c" ]; then
  mkdir -p "$D"
  if curl -fsSL --max-time 120 "https://deb.debian.org/debian/pool/main/m/moreutils/$U" -o /tmp/build/sponge.src 2>/dev/null \
     && tar xJf /tmp/build/sponge.src -C /tmp/build 2>/dev/null; then
    cp -f /tmp/build/moreutils-*/sponge.c "$D/" 2>/dev/null
  fi
fi
[ -f "$D/sponge.c" ] || { echo "  ✗ sponge.c 未找到（下载/解包失败）"; exit 0; }

"$CROSS_CC" $CSIZE "$D/sponge.c" -o /tmp/build/sponge.bin $CLINK \
  && install_verified /tmp/build/sponge.bin sponge \
  || echo "  ✗ sponge 编译失败"
