#!/bin/bash
# tmux.sh —— tmux 3.8 全静态（依赖链：ncurses / libevent 2.1.13 / utf8proc 2.12）
#
# 配方要点（沙箱原型 + iSH 真机全流程验证）：
#   ① configure 无条件查 yacc → CI 必须装 bison（release tarball 也查！已加进 workflow apt）
#   ② ncurses 检测链 tinfow→tinfo→ncursesw→ncurses→AC_SEARCH_LIBS：用 LIBTINFOW_CFLAGS/
#      LIBTINFOW_LIBS 环境变量在第一级直接命中（pkg.m4 的 env 覆盖特性）；libevent/utf8proc
#      同理（LIBEVENT_*/LIBUTF8PROC_*）。ncurses 由 pstree.sh 先建好（同一缓存路径复用）。
#   ③ 源码树是 in-tree 构建：自己用独立目录名（ev/u8/tmuxsrc），避免跨架构/跨工具串对象。
#   ④ iSH 补丁 tmux-ishfix.patch：iSH 未实现 SCM_RIGHTS fd 传递（recvmsg 丢 ancillary cmsg），
#      attach 时服务端收不到客户端终端 fd（IDENTIFY_STDIN -1）→ 按 ttyname 直开客户端终端
#      （沿用 tmux 给 Cygwin 的既有兜底思路）。正常 Linux 上 fd 已由 imsg 送达，此分支
#      永不生效（零影响）。attach 全流程已在 iSH 真机验证（渲染/按键/capture 均正常）。
. "$(dirname "$0")/_common.sh"

# ── 依赖1：ncurses（与 pstree.sh 共用缓存；.done 幂等）──────────────
NCVER=6.5
NCD="/tmp/ncurses-build-$ARCH"
if [ ! -f "$NCD/.done" ]; then
  fetch_gnu "ncurses/ncurses-$NCVER.tar.gz" "ncurses-$NCVER" nc \
    || { echo "  ✗ tmux: ncurses 下载失败（_common 镜像链均不可达）"; exit 0; }
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
[ -f "$NCD/.done" ] || { echo "  ✗ tmux: ncurses 依赖未就绪，跳过"; exit 0; }

# ── 依赖2：libevent（静态）──────────────────────────────────────
EVD="/tmp/libevent-$ARCH"; mkdir -p "$EVD"
if [ ! -f "$EVD/.done" ]; then
  fetch_url "https://github.com/libevent/libevent/releases/download/release-2.1.13-stable/libevent-2.1.13-stable.tar.gz" \
      "libevent-2.1.13-stable" ev \
    || { echo "  ✗ tmux: libevent 下载失败"; exit 0; }
  ( cd /tmp/build/ev \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" ./configure --host="$T" \
         --prefix="$EVD" --disable-shared --enable-static --disable-openssl \
         --disable-libevent-regress --disable-samples --disable-debug-mode >/tmp/c-ev 2>&1 \
    && make -j"$(nproc)" >/tmp/m-ev 2>&1 && make install >/tmp/i-ev 2>&1 \
    && touch "$EVD/.done" ) || echo "  ✗ libevent: $(tail -3 /tmp/m-ev 2>/dev/null | head -1 | cut -c1-110)"
fi
[ -f "$EVD/.done" ] || { echo "  ✗ tmux: libevent 依赖未就绪，跳过"; exit 0; }

# ── 依赖3：utf8proc（静态；tmux 显式 --enable-utf8proc 才用）────────
U8D="/tmp/utf8proc-$ARCH"; mkdir -p "$U8D"
if [ ! -f "$U8D/.done" ]; then
  fetch_url "https://github.com/JuliaStrings/utf8proc/archive/refs/tags/v2.12.0.tar.gz" \
      "utf8proc-2.12.0" u8 \
    || { echo "  ✗ tmux: utf8proc 下载失败"; exit 0; }
  ( cd /tmp/build/u8 \
    && make libutf8proc.a CC="$CROSS_CC" CFLAGS="-Os -fPIC" >/tmp/m-u8 2>&1 \
    && mkdir -p "$U8D/lib" "$U8D/include" \
    && cp libutf8proc.a "$U8D/lib/" && cp utf8proc.h "$U8D/include/" \
    && touch "$U8D/.done" ) || echo "  ✗ utf8proc: $(tail -3 /tmp/m-u8 2>/dev/null | head -1 | cut -c1-110)"
fi
[ -f "$U8D/.done" ] || { echo "  ✗ tmux: utf8proc 依赖未就绪，跳过"; exit 0; }

# ── 主构建 ─────────────────────────────────────────────────
PATCH="$(cd "$(dirname "$0")" && pwd)/tmux-ishfix.patch"
fetch_url "https://github.com/tmux/tmux/releases/download/3.8/tmux-3.8.tar.gz" "tmux-3.8" tmuxsrc \
  || { echo "  ✗ tmux: 下载失败"; exit 0; }
( cd /tmp/build/tmuxsrc \
  && ( grep -q 'iSH: 不支持 SCM_RIGHTS' server-client.c || patch -p1 --batch < "$PATCH" >/tmp/p-tm 2>&1 ) \
  && grep -q 'iSH: 不支持 SCM_RIGHTS' server-client.c \
  && LIBEVENT_CFLAGS="-I$EVD/include" LIBEVENT_LIBS="-L$EVD/lib -levent" \
     LIBTINFOW_CFLAGS="-I$NCD/include -I$NCD/include/ncursesw" LIBTINFOW_LIBS="-L$NCD/lib -lncursesw -ltinfo" \
     LIBUTF8PROC_CFLAGS="-I$U8D/include" LIBUTF8PROC_LIBS="-L$U8D/lib -lutf8proc" \
     CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK -L$NCD/lib -L$EVD/lib -L$U8D/lib" \
     ./configure --host="$T" --enable-static --enable-utf8proc >/tmp/c-tm 2>&1 \
  && make -j"$(nproc)" >/tmp/m-tm 2>&1 \
  && cp tmux /tmp/build/tmux.bin ) \
  && install_verified /tmp/build/tmux.bin tmux \
  || echo "  ✗ tmux: $(grep -iE 'error|Hunk|FAILED' /tmp/m-tm /tmp/c-tm /tmp/p-tm 2>/dev/null | head -1 | cut -c1-110)"
