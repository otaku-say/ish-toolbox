#!/bin/bash
# csvquote.sh —— 让带逗号/换行的 CSV 安全通过 awk/cut 等行工具（dbro/csvquote）
# 用法范式：csvquote < in.csv | awk ... | csvquote -u > out.csv（-u 还原）
. "$(dirname "$0")/_common.sh"

VER=0.1.5
if fetch_url "https://github.com/dbro/csvquote/archive/refs/tags/v$VER.tar.gz" "csvquote-$VER" csvquote; then
  ( cd /tmp/build/csvquote \
    && make CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" >/tmp/m-csvq 2>&1 \
    && cp csvquote /tmp/build/csvquote.bin ) \
    && install_verified /tmp/build/csvquote.bin csvquote \
    || echo "  ✗ csvquote: $(grep -iE 'error|not found' /tmp/m-csvq 2>/dev/null | head -1 | cut -c1-110)"
fi
