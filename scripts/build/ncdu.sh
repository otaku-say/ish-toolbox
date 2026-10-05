#!/bin/bash
# ncdu.sh —— 交互式磁盘分析（C，autotools）
#
# 上游最新：dev.yorhel.nl 官方目录（**不发 GitHub Release**，只能从目录列表挑最新）
# 依赖：musl 版 ncurses（_deps.sh 提供；apt 的 libncurses-dev 对 musl 工具链无效）
. "$(dirname "$0")/_common.sh"
. "$(dirname "$0")/_deps.sh"

VER=$(latest_from_listing "https://dev.yorhel.nl/download/" 'ncdu-[0-9]+\.[0-9]+\.tar\.gz')
[ -z "$VER" ] && { echo "  ! ncdu 版本查询失败"; exit 0; }
echo "  ncdu 上游最新: $VER"

# 官方 release tarball 自带 configure，绕开 autoreconf（CI 上 m4 宏会翻车）
if fetch_url "https://dev.yorhel.nl/download/$VER" "${VER%.tar.gz}" ncdu; then
  ( cd /tmp/build/ncdu \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" ./configure --host="$T" \
         CPPFLAGS="$NCINC" LDFLAGS="$NCLIB -Wl,--gc-sections" \
         --disable-dependency-tracking >/tmp/c-ncdu 2>&1 \
    && make -j"$(nproc)" >/tmp/m-ncdu 2>&1 && cp ncdu /tmp/build/ncdu.bin ) \
    && install_verified /tmp/build/ncdu.bin ncdu \
    || echo "  ✗ ncdu: conf=$(grep -iE 'error|cannot|not found' /tmp/c-ncdu 2>/dev/null | head -1 | cut -c1-70) make=$(grep -iE 'error|cannot|not found' /tmp/m-ncdu 2>/dev/null | head -1 | cut -c1-60)"
fi