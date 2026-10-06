#!/bin/bash
# entr.sh —— 文件变化时执行命令（eradman/entr）
# 构建模型特殊：./configure（无参数）只负责选 Makefile.<os>；编译选项走 make 环境：
#   「CC=... CFLAGS=... make」（静态靠 CFLAGS 里的 -static，实测生效）。
. "$(dirname "$0")/_common.sh"

VER=5.9
if fetch_url "https://github.com/eradman/entr/archive/refs/tags/$VER.tar.gz" "entr-$VER" entr; then
  ( cd /tmp/build/entr \
    && ./configure >/tmp/c-entr 2>&1 \
    && make CC="$CROSS_CC" CFLAGS="$CSIZE" >/tmp/m-entr 2>&1 \
    && cp entr /tmp/build/entr.bin ) \
    && UPX=0 install_verified /tmp/build/entr.bin entr \
    || echo "  ✗ entr: $(grep -iE 'error|not found' /tmp/m-entr /tmp/c-entr 2>/dev/null | head -1 | cut -c1-110)"
fi
