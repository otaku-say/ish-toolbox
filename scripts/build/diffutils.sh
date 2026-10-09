#!/bin/bash
# diffutils.sh —— GNU diffutils 3.12 全静态（交付 diff 单文件）
#
# 要点（2026-10·沙箱双架构实测）：
#   ① 只交付 diff：diff3/sdiff 场景低频；cmp 由 busybox 已提供，不再重复收录
#   ② --disable-nls；strip/UPX/三判据 统一由 install_verified 处理
#   ③ diffutils 3.12 的 gnulib "strcasecmp works" 检查无交叉守卫 →
#      arm64 交叉 configure 报 "cannot run test program while cross compiling"；
#      预置该宏交叉默认值 "guessing yes"（musl 下语义一致）后通过
#   ④ 防跨架构残留：构建前清源码树（旧 .o 混装会报 unknown architecture）
#   ⑤ 失败 exit 1 供 CI 拦截
set -u
. "$(dirname "$0")/_common.sh"

# 版本：默认自动跟随上游最新稳定版；可用 DIFFUTILS_VERSION 显式指定；解析失败回退已知良好版
DV="${DIFFUTILS_VERSION:-}"
[ -z "$DV" ] && { DV=$(latest_gnu diffutils 'diffutils-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz'); DV=${DV#diffutils-}; DV=${DV%.tar.xz}; }
echo "$DV" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$' || DV=3.12
echo "  · diffutils 目标版本：$DV"

if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ diffutils: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 1; }
fi

rm -rf /tmp/build/dfsrc
fetch_gnu "diffutils/diffutils-$DV.tar.xz" "diffutils-$DV" dfsrc \
  || { echo "  ✗ diffutils: 下载失败（_common 镜像链均不可达）"; exit 1; }

( cd /tmp/build/dfsrc \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     ./configure --host="$T" --disable-nls \
       gl_cv_func_strcasecmp_works="guessing yes" >/tmp/c-df 2>&1 \
  && make -j"$(nproc)" >/tmp/m-df 2>&1 \
  && cp src/diff /tmp/build/diff.bin ) \
  || { echo "  ✗ diffutils: $(grep -iE 'error( |:|$)' /tmp/m-df /tmp/c-df 2>/dev/null | head -1 | cut -c1-110)"; exit 1; }

install_verified /tmp/build/diff.bin diff || { echo "  ✗ diffutils: 验证/落盘环节失败"; exit 1; }
