#!/bin/bash
# fzy.sh —— 模糊查找器（jhawthorn/fzy；纯 make，无外部库依赖——实测不需要 ncurses）
. "$(dirname "$0")/_common.sh"

VER=1.1
if fetch_url "https://github.com/jhawthorn/fzy/archive/refs/tags/v$VER.tar.gz" "fzy-$VER" fzy; then
  ( cd /tmp/build/fzy \
    && make CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" >/tmp/m-fzy 2>&1 \
    && cp fzy /tmp/build/fzy.bin ) \
    && UPX=0 install_verified /tmp/build/fzy.bin fzy \
    || echo "  ✗ fzy: $(grep -iE 'error|not found' /tmp/m-fzy 2>/dev/null | head -1 | cut -c1-110)"
fi
