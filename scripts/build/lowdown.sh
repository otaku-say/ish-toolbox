#!/bin/bash
# lowdown.sh —— Markdown → HTML/终端文本/roff（kristapsdz/lowdown）
# 注意：Makefile 是 BSD-make 语法（.ifdef），GNU make 会报 missing separator，
# 必须用 bmake（CI 需安装）；且静态化只能在链接期给：bmake LDFLAGS="$CLINK"。
. "$(dirname "$0")/_common.sh"

VER=VERSION_3_2_1
if fetch_url "https://github.com/kristapsdz/lowdown/archive/refs/tags/$VER.tar.gz" "lowdown-$VER" lowdown; then
  ( cd /tmp/build/lowdown \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" ./configure >/tmp/c-ld 2>&1 \
    && bmake -j"$(nproc)" LDFLAGS="$CLINK" >/tmp/m-ld 2>&1 \
    && cp lowdown /tmp/build/lowdown.bin ) \
    && install_verified /tmp/build/lowdown.bin lowdown \
    || echo "  ✗ lowdown: $(grep -iE 'error|not found' /tmp/m-ld /tmp/c-ld 2>/dev/null | head -1 | cut -c1-110)"
fi
