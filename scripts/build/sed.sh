#!/bin/bash
# sed.sh —— GNU sed 4.10 全静态（GNU 扩展完整：-i 原位编辑 / \xHH / Q / -z / -s）
#
# 要点（2026-10·沙箱双架构实测）：
#   ① 上游只发源码（GNU 官方目录）→ 自编译；产物在 sed/sed 子目录
#   ② --disable-nls：静态精简，不带 libintl
#   ③ 顶层 SUBDIRS 含 gnulib-tests：其 vma-iter.c 需 linux/fs.h（musl 交叉链无此头）
#      且与交付无关 → make 时只构建 "po ." 两个子目录（否则整个 make 因测试目录中断）
#   ④ 防跨架构残留：构建前清源码树（旧 .o 混装会报 unknown architecture）
#   ⑤ strip/UPX/三判据 由 install_verified 统一处理；失败 exit 1 供 CI 拦截
set -u
. "$(dirname "$0")/_common.sh"

SV=4.10
if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ sed: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 1; }
fi

rm -rf /tmp/build/sedsrc
fetch_gnu "sed/sed-$SV.tar.xz" "sed-$SV" sedsrc \
  || { echo "  ✗ sed: 下载失败（_common 镜像链均不可达）"; exit 1; }

( cd /tmp/build/sedsrc \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     ./configure --host="$T" --disable-nls >/tmp/c-sed 2>&1 \
  && make -j"$(nproc)" SUBDIRS="po ." >/tmp/m-sed 2>&1 \
  && cp sed/sed /tmp/build/sed.bin ) \
  || { echo "  ✗ sed: $(grep -iE 'error( |:|$)' /tmp/m-sed /tmp/c-sed 2>/dev/null | head -1 | cut -c1-110)"; exit 1; }

install_verified /tmp/build/sed.bin sed || { echo "  ✗ sed: 验证/落盘环节失败"; exit 1; }
