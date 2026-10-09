#!/bin/bash
# zip.sh —— Info-ZIP zip 3.0 全静态（PKZIP 兼容打包）
#
# 要点（2026-10·沙箱实测）：
#   ① Info-ZIP 无 autotools：走自带 unix/Makefile 的 generic 目标
#      （generic → 先跑 unix/configure 生成 flags → 再编译链接）
#   ② configure 生成的 flags 会固定链接标志，命令行传入的会被覆盖 →
#      适配补丁 zip-10-build.patch 让 LDFLAGS 生效（-static 与 gc-sections
#      经 LDFLAGS 注入；实测无补丁时产物是动态 PIE，补丁后为静态）
#   ③ zip-14-gcc14.patch：兼容 GCC 14+ 的隐式函数声明（CI runner 会滚动升级）
#   ④ 源码链三级回退：SourceForge → BLFS(osuosl) → Debian pool
. "$(dirname "$0")/_common.sh"

# 版本：默认自动跟随上游（Info-ZIP 3.x 稳定线；SourceForge RSS 探测，上游长期静止属正常）；
#       可用 ZIP_VERSION 显式指定；解析失败回退已知良好版 30（=3.0）
ZV="${ZIP_VERSION:-}"
if [ -z "$ZV" ]; then
  ZV=$(curl -fsSL --max-time 60 "https://sourceforge.net/projects/infozip/rss?path=/" 2>/dev/null \
        | grep -oE 'zip3[0-9]+\.tar\.gz' | sort -uV | tail -1)
  ZV=${ZV#zip}; ZV=${ZV%.tar.gz}
fi
echo "$ZV" | grep -qE '^3[0-9]$' || ZV=30
echo "  · zip 目标版本：3.${ZV#3}"

if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ zip: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 0; }
fi

# 源码树全新（同机连跑两架构防残留混装）
rm -rf /tmp/build/ziptmp /tmp/build/zipsrc
ZOK=""
for U in "https://downloads.sourceforge.net/infozip/zip$ZV.tar.gz" \
         "https://ftp.osuosl.org/pub/blfs/conglomeration/zip/zip$ZV.tar.gz" \
         "http://deb.debian.org/debian/pool/main/z/zip/zip_3.0.orig.tar.gz"; do
  curl -fsSL --max-time 300 "$U" -o /tmp/zip.tar.gz 2>/dev/null || continue
  rm -rf /tmp/build/ziptmp; mkdir -p /tmp/build/ziptmp
  tar xzf /tmp/zip.tar.gz -C /tmp/build/ziptmp 2>/dev/null || continue
  SR=$(find /tmp/build/ziptmp -maxdepth 2 -name zip.h 2>/dev/null | head -1)
  [ -n "$SR" ] || continue
  mv "$(dirname "$SR")" /tmp/build/zipsrc && ZOK=1 && break
done
[ -z "$ZOK" ] && { echo "  ✗ zip: 下载失败（三源均不可达）"; exit 0; }

# 适配补丁（存在即按序应用；先取脚本目录绝对路径——应用时已 cd 到源码树，相对路径会失效）
SD=$(cd "$(dirname "$0")" && pwd)
for p in "$SD"/zip-*.patch; do
  [ -f "$p" ] || continue
  ( cd /tmp/build/zipsrc && patch -p1 -s -i "$p" >/dev/null 2>&1 ) \
    || { echo "  ✗ zip: 补丁应用失败 $(basename "$p")"; exit 0; }
done

( cd /tmp/build/zipsrc \
  && LDFLAGS="$CLINK" make -f unix/Makefile CC="$CROSS_CC" LOCAL_ZIP="$CSIZE" generic >/tmp/m-zip 2>&1 \
  && cp zip /tmp/build/zip.bin ) \
  && install_verified /tmp/build/zip.bin zip \
  || echo "  ✗ zip: $(grep -iE 'error' /tmp/m-zip 2>/dev/null | head -1 | cut -c1-110)"
