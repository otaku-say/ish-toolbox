#!/bin/bash
# zstd.sh —— zstd（C，自带 Makefile；静态自编译）
#
# 上游 release 只发源码与 Windows 产物，Linux 静态版自编译。
# 链接参数已实测：musl-gcc（amd64）与 zig cc（arm64）均产出全静态二进制（含 -T 多线程）。
. "$(dirname "$0")/_common.sh"

# 版本：API 查 latest（CI 传入 token 减免限流），失败回退固定版本
U=$(curl -fsSL --max-time 30 ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
      https://api.github.com/repos/facebook/zstd/releases/latest 2>/dev/null \
    | jq -r '.assets[]?.browser_download_url' 2>/dev/null \
    | grep -E 'zstd-[0-9.]+\.tar\.gz$' | head -1)
[ -z "$U" ] && U="https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz"
B=$(basename "$U" .tar.gz)
echo "  zstd 上游: $B"
fetch_url "$U" "$B" zstd-src || { echo "  ✗ zstd 下载失败"; exit 0; }

( cd /tmp/build/zstd-src \
  && make -C programs -j"$(nproc)" zstd CC="$CROSS_CC" \
       CFLAGS="$CSIZE -DZSTD_MULTITHREAD" LDFLAGS="$CLINK -pthread" >/tmp/m-zstd 2>&1 \
  && cp programs/zstd /tmp/build/zstd.bin ) \
  && install_verified /tmp/build/zstd.bin zstd \
  || echo "  ✗ zstd: $(grep -iE 'error' /tmp/m-zstd 2>/dev/null | head -1 | cut -c1-110)"
