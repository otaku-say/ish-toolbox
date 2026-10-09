#!/bin/bash
# grep.sh —— GNU grep 3.12 全静态（含 PCRE2 的 -P 支持）
#
# 要点（2026-10·沙箱实测）：
#   ① -P/--perl-regexp 需要 PCRE2：先静态编 PCRE2（/tmp/deps-pcre2-$ARCH），
#      再用 grep configure 的 PCRE_CFLAGS/PCRE_LIBS 覆盖变量（pkg-config 同名覆盖）
#      静态链入——静态形态运行时无法 dlopen .so，必须链接期解决
#   ② --disable-nls；strip/UPX 统一由 install_verified 处理
. "$(dirname "$0")/_common.sh"

GRV=3.12
PCRE2V=10.49
if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ grep: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 0; }
fi

# 跨架构残留对象防护（同一主机相继编 amd64/arm64 或任何重跑均必需）：源树里
# 残留的前一架构 .o/.a 会被 make 直接复用 → 链接期报 "unknown architecture of
# input file" 或产出错误架构产物——每次构建前清树重编，再 fetch。
# （PCRE2 依赖缓存 /tmp/deps-pcre2-$ARCH 按架构隔离，保留不动。）
rm -rf /tmp/build/grepsrc /tmp/build/pcre2src

# ── 依赖：PCRE2（静态；grep -P 使用）──────────────────────────
PD="/tmp/deps-pcre2-$ARCH"
if [ ! -f "$PD/.done" ]; then
  fetch_url "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$PCRE2V/pcre2-$PCRE2V.tar.gz" \
      "pcre2-$PCRE2V" pcre2src \
    || { echo "  ✗ grep: PCRE2 下载失败"; exit 0; }
  # 注：-all-static 必须走 make 级（libtool 模式标志；进 configure 会污染其
  #     链接探测）。根因：CSIZE 里 -static 在编译期关闭默认 PIE 代码生成
  #     （外部数据走直接 ADRP），而 libtool 会把 -static 当作自己的标志吞掉，
  #     使程序链接退化为工具链默认的 PIE 链接 → arm64 链接必报
  #     R_AARCH64_ADR_PREL_PG_HI21 "may bind externally"（pcre2grep 实锤）。
  #     -all-static 让 libtool 在程序链接里保留 -static（全静态、与代码生成匹配）。
  ( cd /tmp/build/pcre2src \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
       ./configure --host="$T" --prefix="$PD" --disable-shared --enable-static \
           --enable-pcre2-8 --disable-pcre2-16 --disable-pcre2-32 --disable-jit \
           --disable-nls >/tmp/c-pcre2 2>&1 \
    && make -j"$(nproc)" LDFLAGS="$CLINK -all-static" >/tmp/m-pcre2 2>&1 \
    && make install LDFLAGS="$CLINK -all-static" >/tmp/i-pcre2 2>&1 \
    && touch "$PD/.done" ) \
    || echo "  ✗ PCRE2: $(grep -iE 'error:|error [0-9]|undefined reference|cannot find|relocation R_' /tmp/m-pcre2 /tmp/c-pcre2 2>/dev/null | head -1 | cut -c1-110)"
fi
[ -f "$PD/.done" ] || { echo "  ✗ grep: PCRE2 依赖未就绪，跳过"; exit 0; }

fetch_gnu "grep/grep-$GRV.tar.xz" "grep-$GRV" grepsrc \
  || { echo "  ✗ grep: 下载失败（_common 镜像链均不可达）"; exit 0; }

( cd /tmp/build/grepsrc \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     PCRE_CFLAGS="-I$PD/include" PCRE_LIBS="-L$PD/lib -lpcre2-8" \
     PKG_CONFIG_PATH="$PD/lib/pkgconfig" \
     ./configure --host="$T" --disable-nls >/tmp/c-gr 2>&1 \
  && make -j"$(nproc)" >/tmp/m-gr 2>&1 \
  && cp src/grep /tmp/build/grep.bin ) \
  && install_verified /tmp/build/grep.bin grep \
  || echo "  ✗ grep: $(grep -iE 'error:|error [0-9]|undefined reference|cannot find|relocation R_' /tmp/m-gr /tmp/c-gr 2>/dev/null | head -1 | cut -c1-110)"
