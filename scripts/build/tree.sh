#!/bin/bash
# tree.sh —— 目录树展示（上游只有源码、不发任何二进制，纯 C 无外部依赖）
. "$(dirname "$0")/_common.sh"

if fetch Old-Man-Programmer/tree tree; then
  ( cd /tmp/build/tree \
    && make -j"$(nproc)" CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" >/tmp/m-tree 2>&1 \
    && cp tree /tmp/build/tree.bin ) \
    && install_verified /tmp/build/tree.bin tree \
    || echo "  ✗ tree: $(grep -iE 'error' /tmp/m-tree 2>/dev/null | head -1 | cut -c1-110)"
fi
