#!/bin/bash
# xz.sh —— XZ Utils 5.8.4 全静态（xz 单文件；unxz/xzcat/lzma 等经软链名分发）
#
# 要点（2026-10·沙箱实测）：
#   ① 只编 xz 主程序：--disable-xzdec/--disable-lzmadec/--disable-lzmainfo/--disable-scripts
#   ② --disable-nls --disable-shared --disable-doc 静态精简
#   ③ xz 程序链接走 libtool，而 libtool 会**吞掉 -static**（连 CFLAGS 里的也吃，
#      实测链接行只剩 -Wl,--gc-sections，产物是动态 PIE）→ 用 CC 包装器在
#      libtool 视野外补回 -static（编译态带 -static 无副作用，实测 rc=0）
#   ④ argv[0] 分发：以 xz/unxz/xzcat/lzma/unlzma/lzcat 之名调用时行为对应切换（软链即得）
. "$(dirname "$0")/_common.sh"

XV=5.8.4
if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ xz: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 0; }
fi

# 源码树全新（同机连跑两架构防残留混装）
rm -rf /tmp/build/xzsrc
XOK=""
for U in "https://github.com/tukaani-project/xz/releases/download/v$XV/xz-$XV.tar.xz" \
         "https://tukaani.org/xz/xz-$XV.tar.xz"; do
  fetch_url "$U" "xz-$XV" xzsrc && XOK=1 && break
done
[ -z "$XOK" ] && { echo "  ✗ xz: 下载失败（两源均不可达）"; exit 0; }

# libtool 补 -static（见要点③）
printf '#!/bin/sh\nexec %s "$@" -static\n' "$CROSS_CC" > /tmp/xz-cc
chmod +x /tmp/xz-cc

( cd /tmp/build/xzsrc \
  && CC=/tmp/xz-cc CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     ./configure --host="$T" --disable-nls --disable-shared --disable-doc \
         --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-scripts >/tmp/c-xz 2>&1 \
  && make -j"$(nproc)" >/tmp/m-xz 2>&1 \
  && cp src/xz/xz /tmp/build/xz.bin ) \
  && install_verified /tmp/build/xz.bin xz \
  || echo "  ✗ xz: $(grep -iE 'error' /tmp/m-xz /tmp/c-xz 2>/dev/null | head -1 | cut -c1-110)"
