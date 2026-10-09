#!/bin/bash
# tar.sh —— GNU tar 1.35 全静态
#
# 要点（2026-10·沙箱双架构实测）：
#   ① GNU tar 完整特性（--listed-incremental / -a 自动识别压缩 / --exclude-* 等）
#   ② --disable-nls；strip/UPX 统一由 install_verified 处理
. "$(dirname "$0")/_common.sh"

# 版本：默认自动跟随上游最新稳定版；可用 TAR_VERSION 显式指定；解析失败回退已知良好版
TV="${TAR_VERSION:-}"
[ -z "$TV" ] && { TV=$(latest_gnu tar 'tar-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz'); TV=${TV#tar-}; TV=${TV%.tar.xz}; }
echo "$TV" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$' || TV=1.35
echo "  · tar 目标版本：$TV"

if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ tar: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 0; }
fi

# 防跨架构残留：同一源码树在 amd64/arm64（或任意重跑）间复用会混装 .o，
# 链接期报 "unknown architecture of input file" ——故每次构建前清源码树重取。
rm -rf /tmp/build/tarsrc
fetch_gnu "tar/tar-$TV.tar.xz" "tar-$TV" tarsrc \
  || { echo "  ✗ tar: 下载失败（_common 镜像链均不可达）"; exit 0; }

# GNU tar 的 configure 有 root 防呆检查（以 root 跑会致命退出）；容器/CI 里
# 构建常在 root 下进行，统一 FORCE_UNSAFE_CONFIGURE=1 放行（只影响该防呆本身）。
( cd /tmp/build/tarsrc \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" FORCE_UNSAFE_CONFIGURE=1 \
     ./configure --host="$T" --disable-nls >/tmp/c-tar 2>&1 \
  && make -j"$(nproc)" >/tmp/m-tar 2>&1 \
  && cp src/tar /tmp/build/tar.bin ) \
  && install_verified /tmp/build/tar.bin tar \
  || echo "  ✗ tar: $(grep -iE 'error( |:|$)' /tmp/m-tar /tmp/c-tar 2>/dev/null | head -1 | cut -c1-110)"
