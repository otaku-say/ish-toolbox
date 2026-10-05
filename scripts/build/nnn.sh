#!/bin/bash
# nnn.sh —— 终端文件管理器（C，自带 Makefile）
#
# 上游最新：GitHub 默认分支
# 两个关键点：
#   ① musl 没有 fts.h → 用 _deps.sh 编的 musl-fts
#   ② **-DNORL 必须自己带上** —— 命令行传 CPPFLAGS 会覆盖 Makefile 里的
#      `CPPFLAGS += -DNORL`（make 命令行变量优先级最高，+= 追加不上）
. "$(dirname "$0")/_common.sh"
. "$(dirname "$0")/_deps.sh"

if fetch jarun/nnn nnn; then
  ( cd /tmp/build/nnn && make clean >/dev/null 2>&1
    # nnn 的链接命令是 `$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) ... $(LDLIBS)`
    # → LDFLAGS 必须显式传，否则 arm64 的 Zig 会产出动态可执行文件（PT_INTERP）
    make nnn CC="$CROSS_CC" O_NORL=1 \
         CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
         CPPFLAGS="-DNORL $NCINC $FTSINC" \
         LDLIBS="$NCLIB $FTSLIB -lncursesw -Wl,--gc-sections" >/tmp/m-nnn 2>&1 \
    && cp nnn /tmp/build/nnn.bin ) \
    && install_verified /tmp/build/nnn.bin nnn \
    || echo "  ✗ nnn: $(grep -iE 'error|fatal|not found' /tmp/m-nnn 2>/dev/null | head -1 | cut -c1-110)"
fi