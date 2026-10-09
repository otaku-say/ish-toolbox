#!/bin/bash
# findutils.sh —— GNU findutils 4.11.0 全静态（交付 find + xargs 两个单文件）
#
# 要点（2026-10·沙箱双架构实测）：
#   ① 只交付 find / xargs；locate/updatedb 依赖数据库与定时任务，不适合单文件工具箱形态
#   ② --disable-nls；strip/UPX 统一由 install_verified 处理
. "$(dirname "$0")/_common.sh"

FV=4.11.0
if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ findutils: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 0; }
fi

# 防跨架构残留：同一源码树在 amd64/arm64（或任意重跑）间复用会混装 .o，
# 链接期报 "unknown architecture of input file" ——故每次构建前清源码树重取。
rm -rf /tmp/build/fusrc
fetch_gnu "findutils/findutils-$FV.tar.xz" "findutils-$FV" fusrc \
  || { echo "  ✗ findutils: 下载失败（_common 镜像链均不可达）"; exit 0; }

( cd /tmp/build/fusrc \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     ./configure --host="$T" --disable-nls >/tmp/c-fu 2>&1 \
  && make -j"$(nproc)" >/tmp/m-fu 2>&1 \
  && cp find/find /tmp/build/find.bin \
  && cp xargs/xargs /tmp/build/xargs.bin ) \
  && install_verified /tmp/build/find.bin find \
  && install_verified /tmp/build/xargs.bin xargs \
  || echo "  ✗ findutils: $(grep -iE 'error( |:|$)' /tmp/m-fu /tmp/c-fu 2>/dev/null | head -1 | cut -c1-110)"
