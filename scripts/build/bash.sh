#!/bin/bash
# bash.sh —— GNU Bash 5.3 全静态（readline 内建、ncurses 终端库）
#
# 三个实测要点（沙箱原型 + iSH 真机验证）：
#   ① 只编 `make bash` 目标：默认 all 会连带编 support/man2html（宿主工具），
#      交叉时它用宿主 cc 去链目标库而挂掉（2026-10 沙箱实锤）
#   ② --enable-static-link（readline 静态入壳）+ --without-bash-malloc（musl 无需替换）
#   ③ --disable-nls：避免交叉链 glibc 的 libintl 污染静态链接
# 终端能力依赖 ncurses 的 terminfo 搜索配置（iSH 的 terminfo 在 /etc/terminfo）
# —— 与 pstree.sh/tmux.sh 共用 /tmp/ncurses-build-$ARCH 缓存。
. "$(dirname "$0")/_common.sh"

# ── 依赖：ncurses（readline 需要；与 pstree.sh 共用缓存）──────────
NCVER=6.5
NCD="/tmp/ncurses-build-$ARCH"
if [ ! -f "$NCD/.done" ]; then
  fetch_gnu "ncurses/ncurses-$NCVER.tar.gz" "ncurses-$NCVER" nc \
    || { echo "  ✗ bash: ncurses 下载失败（_common 镜像链均不可达）"; exit 0; }
  ( cd /tmp/build/nc \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" ./configure --host="$T" \
         --without-shared --without-debug --without-ada --without-manpages \
         --without-tests --without-progs --without-cxx --without-cxx-binding \
         --prefix="$NCD" \
         --with-terminfo-dirs="/etc/terminfo:/usr/share/terminfo:/usr/lib/terminfo:/lib/terminfo:/usr/local/share/terminfo" \
         --with-fallbacks="xterm-256color,xterm,screen-256color,screen,tmux-256color,vt100,linux,ansi" >/tmp/c-nc 2>&1 \
    && make -j"$(nproc)" >/tmp/m-nc 2>&1 && make install >/tmp/i-nc 2>&1 \
    && ln -sf libncursesw.a "$NCD/lib/libncurses.a" \
    && ln -sf libncursesw.a "$NCD/lib/libtinfo.a" \
    && touch "$NCD/.done" ) || echo "  ✗ ncurses: $(tail -3 /tmp/m-nc 2>/dev/null | head -1 | cut -c1-110)"
fi
[ -f "$NCD/.done" ] || { echo "  ✗ bash: ncurses 依赖未就绪，跳过"; exit 0; }

# ── 主构建 ─────────────────────────────────────────────────
fetch_gnu "bash/bash-5.3.tar.gz" "bash-5.3" bashsrc \
  || { echo "  ✗ bash: 下载失败（_common 镜像链均不可达）"; exit 0; }
( cd /tmp/build/bashsrc \
  && CC="$CROSS_CC" CFLAGS="$CSIZE -I$NCD/include -I$NCD/include/ncursesw" \
     LDFLAGS="$CLINK -L$NCD/lib" LIBS="-lncursesw -ltinfo" \
     ./configure --host="$T" --enable-static-link --without-bash-malloc \
         --with-curses --disable-nls >/tmp/c-ba 2>&1 \
  && make -j"$(nproc)" bash >/tmp/m-ba 2>&1 \
  && cp bash /tmp/build/bash.bin ) \
  && install_verified /tmp/build/bash.bin bash \
  || echo "  ✗ bash: $(grep -iE 'error' /tmp/m-ba /tmp/c-ba 2>/dev/null | head -1 | cut -c1-110)"
