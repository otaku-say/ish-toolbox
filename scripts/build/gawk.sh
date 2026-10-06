#!/bin/bash
# gawk.sh —— GNU Awk 5.4.1 全静态（无扩展/无 MPFR 的自足版）
#
# 要点：
#   ① --disable-extensions：静态构建不能 dlopen 扩展
#   ② --disable-nls：避免交叉链 glibc 的 libintl 污染（同 bash）
#   ③ gawk 5.4 起引入 PMA（持久内存分配器，"PMA Avon" 版本标记属正常）；
#      源码树 in-tree 构建，独立目录名防止跨工具/跨架构串对象
#   ④ 自带 --csv 模式（5.3+），Agent 处理 CSV 的利器
. "$(dirname "$0")/_common.sh"

fetch_gnu "gawk/gawk-5.4.1.tar.xz" "gawk-5.4.1" gawksrc \
  || { echo "  ✗ gawk: 下载失败（_common 镜像链均不可达）"; exit 0; }
( cd /tmp/build/gawksrc \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     ./configure --host="$T" --disable-extensions --disable-mpfr --disable-nls >/tmp/c-gw 2>&1 \
  && make -j"$(nproc)" >/tmp/m-gw 2>&1 \
  && cp gawk /tmp/build/gawk.bin ) \
  && install_verified /tmp/build/gawk.bin gawk \
  || echo "  ✗ gawk: $(grep -iE 'error' /tmp/m-gw /tmp/c-gw 2>/dev/null | head -1 | cut -c1-110)"
