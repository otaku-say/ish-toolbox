#!/bin/bash
# diffstat.sh —— diff 统计（Thomas Dickey；上游只在 invisible-island 目录发 tarball）
. "$(dirname "$0")/_common.sh"

VER=$(latest_from_listing "https://invisible-island.net/archives/diffstat/" 'diffstat-[0-9.]+\.tgz')
[ -z "$VER" ] && { echo "  ! diffstat 版本查询失败"; exit 0; }
echo "  diffstat 上游最新: $VER"

if fetch_url "https://invisible-island.net/archives/diffstat/$VER" "${VER%.tgz}" diffstat; then
  ( cd /tmp/build/diffstat \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
       ./configure --host="$T" >/tmp/c-ds 2>&1 \
    && make -j"$(nproc)" >/tmp/m-ds 2>&1 && cp diffstat /tmp/build/diffstat.bin ) \
    && install_verified /tmp/build/diffstat.bin diffstat \
    || echo "  ✗ diffstat: $(grep -iE 'error|not found' /tmp/m-ds /tmp/c-ds 2>/dev/null | head -1 | cut -c1-110)"
fi
