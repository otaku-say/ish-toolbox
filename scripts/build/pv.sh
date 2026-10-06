#!/bin/bash
# pv.sh —— 管道流量监视器（a-j-wood/pv；autotools）
# ⚠ arm64：pv 的中间步骤用 `ld -r` 做部分链接（不走 $(CC)），host 的 ld 会拒收
#   aarch64 目标文件（"file in wrong format"）→ 把 make 的 LD 指向交叉编译器。
. "$(dirname "$0")/_common.sh"

VER=1.7.24
if fetch_url "https://github.com/a-j-wood/pv/releases/download/v$VER/pv-$VER.tar.gz" "pv-$VER" pv; then
  LDA=""
  [ "$ARCH" = arm64 ] && LDA="LD=$CROSS_CC"
  ( cd /tmp/build/pv \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
       ./configure --host="$T" --disable-nls --disable-dependency-tracking >/tmp/c-pv 2>&1 \
    && make -j"$(nproc)" $LDA >/tmp/m-pv 2>&1 && cp pv /tmp/build/pv.bin ) \
    && install_verified /tmp/build/pv.bin pv \
    || echo "  ✗ pv: $(grep -iE 'error|not found' /tmp/m-pv /tmp/c-pv 2>/dev/null | head -1 | cut -c1-110)"
fi
