#!/bin/bash
# pstree.sh —— 进程树（psmisc 套件里只取 pstree 一个二进制）
# 依赖链：ncurses（宽字符版）→ psmisc。四个实测要点：
#   ① ncurses 只产 libncursesw.a 等 wide 库 → 软链出 libncurses.a/libtinfo.a
#   ② psmisc 只编 src/pstree 目标（fuser 等需要 linux/*.h，与本工具无关）
#   ③ 交叉编译 gnulib 会误判 malloc/realloc"需替换"（rpl_* 未定义）→ cache 变量过掉
#   ④ ncurses 头在 include/ncursesw/ 下：编译要双 -I（层级名 + 本体）
# GNU 源走三镜像链（CI 网络对 ftpmirror/ftp.gnu.org 均可能超时，2026-10 实锤）。
. "$(dirname "$0")/_common.sh"

NCVER=6.5
NCD="/tmp/ncurses-build-$ARCH"
if [ ! -f "$NCD/.done" ]; then
  fetch_gnu "ncurses/ncurses-$NCVER.tar.gz" "ncurses-$NCVER" nc \
    || { echo "  ✗ pstree: ncurses 下载失败（_common 镜像链均不可达）"; exit 0; }
  ( cd /tmp/build/nc \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" ./configure --host="$T" \
         --without-shared --without-debug --without-ada --without-manpages \
         --without-tests --without-progs --without-cxx --without-cxx-binding \
         --prefix="$NCD" >/tmp/c-nc 2>&1 \
    && make -j"$(nproc)" >/tmp/m-nc 2>&1 && make install >/tmp/i-nc 2>&1 \
    && ln -sf libncursesw.a "$NCD/lib/libncurses.a" \
    && ln -sf libncursesw.a "$NCD/lib/libtinfo.a" \
    && touch "$NCD/.done" ) || echo "  ✗ ncurses: $(tail -3 /tmp/m-nc 2>/dev/null | head -1 | cut -c1-110)"
fi
[ -f "$NCD/.done" ] || { echo "  ✗ pstree: ncurses 依赖未就绪，跳过"; exit 0; }

PVER=23.7
PS_OK=""
for U in "https://deb.debian.org/debian/pool/main/p/psmisc/psmisc_$PVER.orig.tar.xz|psmisc-$PVER" \
         "https://mirrors.edge.kernel.org/debian/pool/main/p/psmisc/psmisc_$PVER.orig.tar.xz|psmisc-$PVER" \
         "https://ftp.osuosl.org/pub/blfs/conglomeration/psmisc/psmisc-$PVER.tar.xz|psmisc-$PVER"; do
  UU=${U%%|*}; DD=${U#*|}
  if fetch_url "$UU" "$DD" psmisc; then PS_OK=1; break; fi
done
[ -z "$PS_OK" ] && { echo "  ✗ pstree: psmisc 下载失败（三源均不可达）"; exit 0; }
if true; then
  ( cd /tmp/build/psmisc \
    && ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes \
       CC="$CROSS_CC" CFLAGS="$CSIZE -I$NCD/include -I$NCD/include/ncursesw" LDFLAGS="$CLINK -L$NCD/lib" \
       ./configure --host="$T" --disable-nls --disable-dependency-tracking >/tmp/c-ps 2>&1 \
    && make -j"$(nproc)" src/pstree CPPFLAGS="-I$NCD/include -I$NCD/include/ncursesw" CFLAGS="$CSIZE" >/tmp/m-ps 2>&1 \
    && cp src/pstree /tmp/build/pstree.bin ) \
    && UPX=0 install_verified /tmp/build/pstree.bin pstree \
    || echo "  ✗ pstree: $(grep -iE 'error|not found' /tmp/m-ps /tmp/c-ps 2>/dev/null | head -1 | cut -c1-110)"
fi
