#!/bin/bash
# unzip.sh —— Info-ZIP Unzip 6.0 全静态（PKZIP 兼容解包；含完整安全补丁）
#
# 要点（2026-10·沙箱实测）：
#   ① Info-ZIP 无 autotools：make -f unix/Makefile unzips
#      编译器走 CC；体积/静态标志走 CF（仅 flags，含 -static）；链接标志走 LF2
#      -no-pie 强制非 PIE（musl.cc 等交叉链默认可能产出 static-pie，与仓库现有产物不一致）
#   ② 上游长期静止（6.0 为最终版，2009 起不再发版）→ 不做版本探测；
#      源码 4 级回退：Alpine archive → SourceForge → BLFS(osuosl) → Debian pool
#   ③ 补丁 30 个（unzip-patches/，与 Alpine aports 同源）：
#      CVE 全量修复（2014–2022）/ zipbomb 防护（part1-7+switch）/ PKWARE 验证位 /
#      时间戳精确还原 / 符号链接与属主修复 / GCC14/15 兼容 / 去构建时间戳
#   ④ 不含 -O/-I 字符集转换（旧发行版专属补丁，现代 Debian/Alpine 均已移除；
#      GBK 名称场景见 tools/unzip/USAGE.md 的 python 转换法）
. "$(dirname "$0")/_common.sh"

if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ unzip: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 0; }
fi

# 源码树全新（同机连跑两架构防残留混装）
rm -rf /tmp/build/unziptmp /tmp/build/unzipsrc
UOK=""
for U in "https://dev.alpinelinux.org/archive/unzip/unzip60.tgz" \
         "https://downloads.sourceforge.net/infozip/unzip60.tar.gz" \
         "https://ftp.osuosl.org/pub/blfs/conglomeration/unzip/unzip60.tar.gz" \
         "http://deb.debian.org/debian/pool/main/u/unzip/unzip_6.0.orig.tar.gz"; do
  curl -fsSL --max-time 300 "$U" -o /tmp/unzip.tgz 2>/dev/null || continue
  rm -rf /tmp/build/unziptmp; mkdir -p /tmp/build/unziptmp
  tar xzf /tmp/unzip.tgz -C /tmp/build/unziptmp 2>/dev/null || continue
  SR=$(find /tmp/build/unziptmp -maxdepth 2 -name unzip.h 2>/dev/null | head -1)
  [ -n "$SR" ] || continue
  mv "$(dirname "$SR")" /tmp/build/unzipsrc && UOK=1 && break
done
[ -z "$UOK" ] && { echo "  ✗ unzip: 下载失败（四源均不可达）"; exit 0; }

# 补丁（目录内按文件名序应用；先取脚本目录绝对路径——应用时已 cd 到源码树）
SD=$(cd "$(dirname "$0")" && pwd)
PD="$SD/unzip-patches"
for p in $(ls "$PD" 2>/dev/null | sort); do
  [ -f "$PD/$p" ] || continue
  ( cd /tmp/build/unzipsrc && patch -p1 -s -i "$PD/$p" >/dev/null 2>&1 ) \
    || { echo "  ✗ unzip: 补丁应用失败 $p"; exit 0; }
done

DEFS="-DACORN_FTYPE_NFS -DWILD_STOP_AT_DIR -DLARGE_FILE_SUPPORT -DUNICODE_SUPPORT -DUNICODE_WCHAR -DUTF8_MAYBE_NATIVE -DNO_LCHMOD -DDATE_FORMAT=DF_YMD -DNOMEMCPY -DNO_WORKING_ISPRINT"
( cd /tmp/build/unzipsrc \
  && make -f unix/Makefile CC="$CROSS_CC" LF2="$CLINK -no-pie" \
       CF="-I. $CSIZE $DEFS -no-pie" prefix=/usr unzips >/tmp/m-unzip 2>&1 \
  && cp unzip /tmp/build/unzip.bin ) \
  && install_verified /tmp/build/unzip.bin unzip \
  || echo "  ✗ unzip: $(grep -iE 'error' /tmp/m-unzip 2>/dev/null | head -1 | cut -c1-110)"
