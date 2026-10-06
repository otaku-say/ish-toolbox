#!/bin/bash
# envsubst.sh —— 环境变量替换（GNU gettext-runtime 的 envsubst；自编译）
# 从 gettext 发行包内嵌的 gettext-runtime 子包单独构建（不整包编译）。
# libtool 项目：最终静态化必须 make LDFLAGS="-no-pie -all-static"（-static 会被吞）。
# 取源策略（2026-10 实测网络多变）：多版本 × 多镜像，debian 池兜底——
#   GNU 侧：kernel.org（最稳）→ ftpmirror → ftp.gnu.org；版本 1.0 → 0.26
#   Debian：gettext_<ver>.orig.tar.xz（CI 上 deb.debian.org 连接最可靠）
. "$(dirname "$0")/_common.sh"

GT_OK=""
for V in 1.0 0.26; do
  for M in "https://mirrors.kernel.org/gnu/gettext" "https://ftpmirror.gnu.org/gnu/gettext" "https://ftp.gnu.org/gnu/gettext"; do
    if fetch_url "$M/gettext-$V.tar.xz" "gettext-$V" gettext; then GT_OK=1; break 2; fi
  done
done
if [ -z "$GT_OK" ]; then
  for N in "gettext_1.0.orig.tar.xz:gettext-1.0" "gettext_0.23.1.orig.tar.xz:gettext-0.23.1"; do
    F=${N%%:*}; D=${N#*:}
    if fetch_url "https://deb.debian.org/debian/pool/main/g/gettext/$F" "$D" gettext; then GT_OK=1; break; fi
  done
fi
[ -z "$GT_OK" ] && { echo "  ✗ envsubst: gettext 源码获取失败（GNU 三镜像 + debian 池均不可达）"; exit 0; }

( cd /tmp/build/gettext/gettext-runtime \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     ./configure --host="$T" --disable-dependency-tracking >/tmp/c-gt 2>&1 \
  && make -j"$(nproc)" LDFLAGS="-no-pie -all-static" >/tmp/m-gt 2>&1 \
  && cp src/envsubst /tmp/build/envsubst.bin ) \
  && UPX=0 install_verified /tmp/build/envsubst.bin envsubst \
  || echo "  ✗ envsubst: $(grep -iE 'error|not found' /tmp/m-gt /tmp/c-gt 2>/dev/null | head -1 | cut -c1-110)"
