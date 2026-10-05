#!/bin/bash
# fzy.sh —— 模糊选择器（C，单仓库多文件）
#
# 上游最新：GitHub 默认分支 master（无 Release 二进制）
# 体积要点：Makefile 链接时只用 $(CFLAGS) 不用 $(LDFLAGS)，
#           所以 -static 必须出现在 CSIZE 里（见 _common.sh）
set -e
. "$(dirname "$0")/_common.sh"

if fetch jhawthorn/fzy fzy; then
  # 源码在 src/ 下（fzy.c + match.c + tty.c + choices.c + options.c + tty_interface.c）
  ( cd /tmp/build/fzy && make clean >/dev/null 2>&1 \
    && make CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" >/tmp/e-fzy 2>&1 \
    && cp fzy /tmp/build/fzy.bin ) \
    && install_verified /tmp/build/fzy.bin fzy \
    || echo "  ✗ fzy: $(head -3 /tmp/e-fzy 2>/dev/null | tr '\n' ' ')"
fi