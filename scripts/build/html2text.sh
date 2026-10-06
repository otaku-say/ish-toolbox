#!/bin/bash
# html2text.sh —— HTML → 纯文本（grobian/html2text，C++，autotools；上游无二进制）
# C++ 编译用 zig c++（两架构统一：自带 libc++ + musl，避免混搭 gcc/zig 的 libc 不一致）。
# ⚠ zig 的 target 必须用三段的规范形（x86_64-linux-musl / aarch64-linux-musl）：
#   四段式（带 -unknown-）会被 zig c++ 拒绝报 "UnknownOperatingSystem"（2026-10 实锤）。
. "$(dirname "$0")/_common.sh"

VER=2.3.0
ZT=$(printf '%s' "$T" | sed 's/-unknown-/-/')
printf '#!/bin/sh\nexec zig c++ -target %s "$@"\n' "$ZT" > /tmp/zigcxx
printf '#!/bin/sh\nexec zig cc -target %s "$@"\n' "$ZT" > /tmp/zigcc-html
chmod +x /tmp/zigcxx /tmp/zigcc-html

if fetch_url "https://github.com/grobian/html2text/releases/download/v$VER/html2text-$VER.tar.gz" "html2text-$VER" html2text; then
  ( cd /tmp/build/html2text \
    && ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes \
       gl_cv_func_malloc_0_nonnull=yes gl_cv_func_realloc_0_nonnull=yes \
       CC=/tmp/zigcc-html CXX=/tmp/zigcxx CFLAGS="$CSIZE" CXXFLAGS="$CSIZE" LDFLAGS="$CLINK" \
       ./configure --host="$T" --disable-dependency-tracking >/tmp/c-h2t 2>&1 \
    && make -j"$(nproc)" >/tmp/m-h2t 2>&1 && cp html2text /tmp/build/h2t.bin ) \
    && UPX=0 install_verified /tmp/build/h2t.bin html2text \
    || { echo "  ✗ html2text: $(grep -iE 'error|not found' /tmp/m-h2t /tmp/c-h2t 2>/dev/null | head -1 | cut -c1-110)"; tail -6 /tmp/c-h2t 2>/dev/null | sed 's/^/      | /'; }
fi
