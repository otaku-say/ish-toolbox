#!/bin/bash
# envsubst.sh —— 环境变量替换（GNU gettext-runtime 的 envsubst；自编译）
# 从 gettext 发行包内嵌的 gettext-runtime 子包单独构建（不整包编译）。
# libtool 项目：最终静态化必须 make LDFLAGS="-no-pie -all-static"（-static 会被吞）。
# GNU 源走三镜像链（CI 网络对 ftp.gnu.org/ftpmirror 均可能超时，2026-10 实锤）。
. "$(dirname "$0")/_common.sh"

VER=""
for M in "https://mirrors.kernel.org/gnu/gettext/" "https://ftpmirror.gnu.org/gnu/gettext/" "https://ftp.gnu.org/gnu/gettext/"; do
  VER=$(latest_from_listing "$M" 'gettext-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz')
  [ -n "$VER" ] && break
done
[ -z "$VER" ] && { echo "  ! envsubst 版本查询失败（三镜像均不可达）"; exit 0; }
echo "  gettext 上游最新: $VER"

GT_OK=""
for M in "https://mirrors.kernel.org/gnu/gettext" "https://ftpmirror.gnu.org/gnu/gettext" "https://ftp.gnu.org/gnu/gettext"; do
  if fetch_url "$M/$VER" "${VER%.tar.xz}" gettext; then GT_OK=1; break; fi
  echo "  ! 镜像不可达：$M"
done
[ -z "$GT_OK" ] && { echo "  ✗ envsubst: gettext 下载失败（三镜像均不可达）"; exit 0; }

( cd /tmp/build/gettext/gettext-runtime \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     ./configure --host="$T" --disable-dependency-tracking >/tmp/c-gt 2>&1 \
  && make -j"$(nproc)" LDFLAGS="-no-pie -all-static" >/tmp/m-gt 2>&1 \
  && cp src/envsubst /tmp/build/envsubst.bin ) \
  && UPX=0 install_verified /tmp/build/envsubst.bin envsubst \
  || echo "  ✗ envsubst: $(grep -iE 'error|not found' /tmp/m-gt /tmp/c-gt 2>/dev/null | head -1 | cut -c1-110)"
