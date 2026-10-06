#!/bin/bash
# xxhsum.sh —— xxHash 校验和 CLI（xxHash 官方；纯 make 直编，无 configure）
. "$(dirname "$0")/_common.sh"

VER=0.8.4
if fetch_url "https://github.com/Cyan4973/xxHash/archive/refs/tags/v$VER.tar.gz" "xxHash-$VER" xxh; then
  ( cd /tmp/build/xxh \
    && make xxhsum CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" >/tmp/m-xxh 2>&1 \
    && cp xxhsum /tmp/build/xxhsum.bin ) \
    && UPX=0 install_verified /tmp/build/xxhsum.bin xxhsum \
    || echo "  ✗ xxhsum: $(grep -iE 'error|not found' /tmp/m-xxh 2>/dev/null | head -1 | cut -c1-110)"
fi
