#!/bin/bash
# patch.sh —— GNU patch（C，autotools）
#
# 上游最新：GNU 官方 ftp 目录（**不使用 GitHub 镜像**——之前用
#           archive tarball + autoreconf 路线失败，因为 CI 上 m4 宏环境有问题；
#           官方 release tarball 自带 configure，直接绕开）
. "$(dirname "$0")/_common.sh"

VER=$(latest_from_listing "https://ftp.gnu.org/gnu/patch/" 'patch-[0-9]+\.[0-9]+\.tar\.gz')
[ -z "$VER" ] && { echo "  ! patch 版本查询失败"; exit 0; }
echo "  patch 上游最新: $VER"

if fetch_url "https://ftp.gnu.org/gnu/patch/$VER" "${VER%.tar.gz}" patch; then
  ( cd /tmp/build/patch \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
       ./configure --host="$T" --disable-dependency-tracking >/tmp/c-patch 2>&1 \
    && make -j"$(nproc)" >/tmp/m-patch 2>&1 && cp src/patch /tmp/build/patch.bin ) \
    && install_verified /tmp/build/patch.bin patch \
    || echo "  ✗ patch: $(grep -iE 'error|not found' /tmp/m-patch /tmp/c-patch 2>/dev/null | head -1 | cut -c1-110)"
fi