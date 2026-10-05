#!/bin/bash
# stdbuf.sh —— stdbuf（轻量兼容实现，自编译）
#
# 两个产物（同目录成对部署）：
#   stdbuf         启动器（全静态）：解析 -i/-o/-e MODE → 写 _STDBUF_* 环境变量
#                  → 将同目录 libstdbuf.so 前置到 LD_PRELOAD → exec 目标命令
#   libstdbuf.so   注入库（共享）：constructor 中按 _STDBUF_* 对 stdin/stdout/stderr
#                  调 setvbuf（L=行缓冲 / 0=无缓冲 / N 字节全缓冲）
# 说明：与 GNU stdbuf 语义兼容（-oL / -o L / --output= 均可）；
#       静态子进程无动态加载器、无法被注入；动态 musl 程序（busybox 等）可用。
# 为什么不用 GNU coreutils：其交叉构建牵扯 gnulib 生成头 + 宿主内核头，
# 成本远超收益（细节记录于仓库提交历史）。
. "$(dirname "$0")/_common.sh"
SRCD="$(cd "$(dirname "$0")" && pwd)"

"$CROSS_CC" $CSIZE -D_GNU_SOURCE "$SRCD/stdbuf-launcher.c" -o /tmp/build/stdbuf.bin $CLINK \
  && install_verified /tmp/build/stdbuf.bin stdbuf \
  || { echo "  ✗ stdbuf 启动器编译失败"; exit 0; }

"$CROSS_CC" -shared -Os -fPIC "$SRCD/stdbuf-lib.c" -o /tmp/build/libstdbuf.so 2>/tmp/m-so.log \
  || { echo "  ✗ libstdbuf.so 编译失败: $(head -1 /tmp/m-so.log | cut -c1-100)"; exit 0; }
em=$(od -An -tx1 -j18 -N1 /tmp/build/libstdbuf.so | tr -d ' \n')
[ "$em" = "$EM" ] || { echo "  ✗ libstdbuf.so 架构不符（$em ≠ $EM）"; exit 0; }
strip /tmp/build/libstdbuf.so 2>/dev/null || true
cp /tmp/build/libstdbuf.so "$OUT/libstdbuf.so" && chmod 755 "$OUT/libstdbuf.so"
echo "  ✓ libstdbuf.so 已配套（$(wc -c < "$OUT/libstdbuf.so") bytes）"
