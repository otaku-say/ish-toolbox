#!/bin/bash
# html2text.sh —— HTML → 纯文本（grobian/html2text，C++，autotools；上游无二进制）
# C++ 编译用 zig c++（两架构统一：自带 libc++ + musl，避免 musl-gcc(C) 与
# zig(C++) 混搭导致 libc 不一致；CI 的 amd64 腿同样需要 zig，workflow 已装）。
. "$(dirname "$0")/_common.sh"

VER=2.3.0
CXX_W=/tmp/zigcxx
[ -x "$CXX_W" ] || { printf '#!/bin/sh\nexec zig c++ -target %s "$@"\n' "$T" > "$CXX_W"; chmod +x "$CXX_W"; }
CC_W=/tmp/zigcc
[ -x "$CC_W" ] || { printf '#!/bin/sh\nexec zig cc -target %s "$@"\n' "$T" > "$CC_W"; chmod +x "$CC_W"; }

if fetch_url "https://github.com/grobian/html2text/releases/download/v$VER/html2text-$VER.tar.gz" "html2text-$VER" html2text; then
  ( cd /tmp/build/html2text \
    && CC="$CC_W" CXX="$CXX_W" CFLAGS="$CSIZE" CXXFLAGS="$CSIZE" LDFLAGS="$CLINK" \
       ./configure --host="$T" --disable-dependency-tracking >/tmp/c-h2t 2>&1 \
    && make -j"$(nproc)" >/tmp/m-h2t 2>&1 && cp html2text /tmp/build/h2t.bin ) \
    && UPX=0 install_verified /tmp/build/h2t.bin html2text \
    || echo "  ✗ html2text: $(grep -iE 'error|not found' /tmp/m-h2t /tmp/c-h2t 2>/dev/null | head -1 | cut -c1-110)"
fi
