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
  # 自动回退：先试上游最新，交叉编译失败则退到已知可用的 6.4
  # （实测 6.6 在本 CI 的交叉编译环境下会失败，但下载本身是好的）
  for cand in "$NCV" "ncurses-6.4.tar.gz"; do
    [ -z "$cand" ] && continue
    rm -rf /tmp/build/ncsrc
    if fetch_url "https://invisible-mirror.net/archives/ncurses/$cand" "${cand%.tar.gz}" ncsrc \
       && ( cd /tmp/build/ncsrc \
            && ./configure --host="$T" CC="$CROSS_CC" CFLAGS="-Os" \
                 --prefix=/tmp/nc-prefix --without-shared --without-debug --without-ada \
                 --enable-widec --without-manpages --without-tests >/tmp/c-nc 2>&1 \
            && make -j"$(nproc)" >/tmp/m-nc 2>&1 && make install >/dev/null 2>&1 ); then
      echo "  ✓ ncurses(musl) 就绪（$cand）"; break
    fi
    echo "  ! $cand 编译失败，回退重试…"
  done
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
