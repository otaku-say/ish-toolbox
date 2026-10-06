#!/bin/bash
# pstree.sh —— 进程树（psmisc 套件里只取 pstree 一个二进制）
# 依赖链：ncurses（宽字符版）→ psmisc。三个实测要点：
#   ① 本配方构建的 ncurses 只产 libncursesw.a 等 wide 库 → 软链出
#      libncurses.a / libtinfo.a，供 psmisc 的 AC_SEARCH_LIBS(tgetent…) 命中
#   ② psmisc 只编 src/pstree 目标（fuser 等需要 linux/*.h，与本工具无关）
#   ③ 交叉编译 gnulib 会把 malloc/realloc 误判为"需替换"（rpl_*）——
#      用 ac_cv_func_{malloc,realloc}_0_nonnull=yes 过掉（arm64/zig 实测必须）
#   ④ ncurses 头在 include/ncursesw/ 子目录：编译要双 -I（层级名 + 本体）
. "$(dirname "$0")/_common.sh"

NCVER=6.5
NCD="/tmp/ncurses-build-$ARCH"
if [ ! -f "$NCD/.done" ]; then
  if fetch_url "https://ftpmirror.gnu.org/gnu/ncurses/ncurses-$NCVER.tar.gz" "ncurses-$NCVER" nc; then
    ( cd /tmp/build/nc \
      && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" ./configure --host="$T" \
           --without-shared --without-debug --without-ada --without-manpages \
           --without-tests --prefix="$NCD" >/tmp/c-nc 2>&1 \
      && make -j"$(nproc)" >/tmp/m-nc 2>&1 && make install >/tmp/i-nc 2>&1 \
      && ln -sf libncursesw.a "$NCD/lib/libncurses.a" \
      && ln -sf libncursesw.a "$NCD/lib/libtinfo.a" \
      && touch "$NCD/.done" ) || echo "  ✗ ncurses: $(tail -3 /tmp/m-nc 2>/dev/null | head -1 | cut -c1-110)"
  fi
fi
[ -f "$NCD/.done" ] || { echo "  ✗ pstree: ncurses 依赖未就绪，跳过"; exit 0; }

PVER=23.7
if fetch_url "https://deb.debian.org/debian/pool/main/p/psmisc/psmisc_$PVER.orig.tar.xz" "psmisc-$PVER" psmisc; then
  ( cd /tmp/build/psmisc \
    && ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes \
       CC="$CROSS_CC" CFLAGS="$CSIZE -I$NCD/include -I$NCD/include/ncursesw" LDFLAGS="$CLINK -L$NCD/lib" \
       ./configure --host="$T" --disable-nls --disable-dependency-tracking >/tmp/c-ps 2>&1 \
    && make -j"$(nproc)" src/pstree CPPFLAGS="-I$NCD/include -I$NCD/include/ncursesw" CFLAGS="$CSIZE" >/tmp/m-ps 2>&1 \
    && cp src/pstree /tmp/build/pstree.bin ) \
    && UPX=0 install_verified /tmp/build/pstree.bin pstree \
    || echo "  ✗ pstree: $(grep -iE 'error|not found' /tmp/m-ps /tmp/c-ps 2>/dev/null | head -1 | cut -c1-110)"
fi
