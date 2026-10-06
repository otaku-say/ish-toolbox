#!/bin/bash
# envsubst.sh —— 环境变量替换（GNU gettext-runtime 的 envsubst；自编译）
# gettext-runtime 子包单独构建；静态化必须 make LDFLAGS="-no-pie -all-static"。
# 取源：统一 GNU 镜像链（_common：kernel.org/清华/阿里）；listing→版本候选→
# Debian 池 三级兜底（gettext-1.0 曾因镜像未齐 + tar xz 解压 bug 连环翻车）。
. "$(dirname "$0")/_common.sh"

GT_OK=""
VER=$(latest_gnu gettext 'gettext-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz' || true)
echo "  gettext 上游最新: ${VER:-（listing 不可用，转候选版本）}"
[ -n "$VER" ] && fetch_gnu "gettext/$VER" "${VER%.tar.xz}" gettext && GT_OK=1
if [ -z "$GT_OK" ]; then
  for V in 1.0 0.26; do
    if fetch_gnu "gettext/gettext-$V.tar.xz" "gettext-$V" gettext; then GT_OK=1; break; fi
  done
fi
if [ -z "$GT_OK" ]; then
  for N in "gettext_1.0.orig.tar.xz:gettext-1.0" "gettext_0.23.1.orig.tar.xz:gettext-0.23.1"; do
    F=${N%%:*}; D=${N#*:}
    if fetch_url "https://deb.debian.org/debian/pool/main/g/gettext/$F" "$D" gettext; then GT_OK=1; break; fi
  done
fi
[ -z "$GT_OK" ] && { echo "  ✗ envsubst: gettext 源码获取失败（镜像链 + Debian 池均不可达）"; exit 0; }

( cd /tmp/build/gettext/gettext-runtime \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     ./configure --host="$T" --disable-dependency-tracking >/tmp/c-gt 2>&1 \
  && make -j"$(nproc)" LDFLAGS="-no-pie -all-static" >/tmp/m-gt 2>&1 \
  && cp src/envsubst /tmp/build/envsubst.bin ) \
  && UPX=0 install_verified /tmp/build/envsubst.bin envsubst \
  || echo "  ✗ envsubst: $(grep -iE 'error|not found' /tmp/m-gt /tmp/c-gt 2>/dev/null | head -1 | cut -c1-110)"
