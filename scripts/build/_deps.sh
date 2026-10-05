#!/bin/bash
# _deps.sh —— nnn / ncdu 的公共依赖：musl 版 ncurses + musl-fts
#
# 为什么必须自编：musl-gcc 与 Zig 都**不搜 /usr/include**（那是 glibc 的头），
# 所以 apt 装的 libncurses-dev 对它们毫无用处；musl 也不带 fts.h（glibc 专有）。
# 本脚本幂等，编过一次就跳过。
. "$(dirname "$0")/_common.sh"

if [ ! -f /tmp/nc-prefix/lib/libncursesw.a ]; then
  echo "  → 编译 musl 版 ncurses（$ARCH）"
  NCV=$(latest_from_listing "https://invisible-mirror.net/archives/ncurses/" 'ncurses-[0-9]+\.[0-9]+\.tar\.gz')
  [ -z "$NCV" ] && NCV=ncurses-6.4.tar.gz
  echo "    ncurses 最新: $NCV"
  fetch_url "https://invisible-mirror.net/archives/ncurses/$NCV" "${NCV%.tar.gz}" ncsrc \
    && ( cd /tmp/build/ncsrc \
         && ./configure --host="$T" CC="$CROSS_CC" CFLAGS="-Os" \
              --prefix=/tmp/nc-prefix --without-shared --without-debug --without-ada \
              --enable-widec --without-manpages --without-tests >/tmp/c-nc 2>&1 \
         && make -j"$(nproc)" >/tmp/m-nc 2>&1 && make install >/dev/null 2>&1 ) \
    && echo "  ✓ ncurses(musl) 就绪" \
    || echo "  ! ncurses 失败: $(tail -2 /tmp/c-nc 2>/dev/null | head -1)"
fi
export NCINC="-I/tmp/nc-prefix/include -I/tmp/nc-prefix/include/ncursesw"
export NCLIB="-L/tmp/nc-prefix/lib"

if [ ! -f /tmp/fts-prefix/lib/libfts.a ]; then
  echo "  → 编译 musl-fts（nnn 需要 fts.h，musl 不带）"
  if fetch pullmoll/musl-fts musl-fts; then
    ( cd /tmp/build/musl-fts \
      && (./bootstrap.sh >/tmp/b-fts 2>&1 || autoreconf -fi >>/tmp/b-fts 2>&1) \
      && CC="$CROSS_CC" ./configure --host="$T" CFLAGS="-Os" --prefix=/tmp/fts-prefix >/tmp/c-fts 2>&1 \
      && make -j"$(nproc)" >/tmp/m-fts 2>&1 && make install >/dev/null 2>&1 ) \
      && echo "  ✓ musl-fts 就绪" \
      || echo "  ! musl-fts 失败: $(tail -2 /tmp/c-fts 2>/dev/null | head -1)"
  fi
fi
export FTSINC="-I/tmp/fts-prefix/include" FTSLIB="-L/tmp/fts-prefix/lib -lfts"
