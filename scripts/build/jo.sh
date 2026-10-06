#!/bin/bash
# jo.sh —— 从命令行参数生成 JSON（jpmens/jo，C，autotools；上游无二进制）
# 注意：release tag 是「1.9」不带 v 前缀（踩过 404）。
. "$(dirname "$0")/_common.sh"

VER=1.9
if fetch_url "https://github.com/jpmens/jo/releases/download/$VER/jo-$VER.tar.gz" "jo-$VER" jo; then
  ( cd /tmp/build/jo \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
       ./configure --host="$T" --disable-dependency-tracking >/tmp/c-jo 2>&1 \
    && make -j"$(nproc)" >/tmp/m-jo 2>&1 && cp jo /tmp/build/jo.bin ) \
    && UPX=0 install_verified /tmp/build/jo.bin jo \
    || echo "  ✗ jo: $(grep -iE 'error|not found' /tmp/m-jo /tmp/c-jo 2>/dev/null | head -1 | cut -c1-110)"
fi
