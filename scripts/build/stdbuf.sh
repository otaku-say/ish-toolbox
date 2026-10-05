#!/bin/bash
# stdbuf.sh —— stdbuf（coreutils 定向构建）
#
# 产物两个文件：
#   stdbuf         主程序（全静态）
#   libstdbuf.so   共享库（运行期由 stdbuf 经 LD_PRELOAD 注入子进程调整缓冲，GNU 同款机制）
# 说明：静态子进程无动态加载器、无法被注入；动态 musl 程序（busybox 等）可用。
# 构建要点（沙箱实测）：
#   · src/libstdbuf.so 可独立构建（不依赖生成的 configmake.h）
#   · src/stdbuf 依赖 configmake.h/version.h —— 只在“全量 make”链路里生成，
#     故先跑一遍全量（允许部分失败），再定向静态重链 stdbuf
. "$(dirname "$0")/_common.sh"

VER=$(latest_from_listing "https://ftp.gnu.org/gnu/coreutils/" 'coreutils-[0-9.]+\.tar\.xz' | sort -uV | tail -1)
[ -z "$VER" ] && { echo "  ! coreutils 版本查询失败"; exit 0; }
echo "  coreutils 上游: $VER"

D=/tmp/build/coreutils
if [ ! -f "$D/src/stdbuf" ] || [ ! -f "$D/src/libstdbuf.so" ]; then
  mkdir -p /tmp/build
  curl -fsSL --max-time 240 "https://ftp.gnu.org/gnu/coreutils/$VER.tar.xz" -o /tmp/build/cu.txz 2>/dev/null \
    && { rm -rf "$D"; tar xJf /tmp/build/cu.txz -C /tmp/build 2>/dev/null && mv "/tmp/build/$VER" "$D" 2>/dev/null; } \
    || { echo "  ✗ coreutils 下载/解包失败"; exit 0; }
fi

cd "$D"
FORCE_UNSAFE_CONFIGURE=1 CC="$CROSS_CC" ./configure --host="$T" --disable-nls >/tmp/c-cu 2>&1 \
  || { echo "  ✗ coreutils configure 失败"; exit 0; }

# 1) 共享库先建（独立可行，先锁定这个关键产物）
make -j"$(nproc)" src/libstdbuf.so >/tmp/m-cu1 2>&1 || true

# 2) 全量 make：生成 configmake.h / version.h 等全部生成物（允许失败）
make -j"$(nproc)" >/tmp/m-cu-all 2>&1 || echo "  ! coreutils 全量构建未全过（继续尝试目标件）"

# 3) 定向静态重链 stdbuf（此时头文件已齐全）
rm -f src/stdbuf
make -j"$(nproc)" src/stdbuf LDFLAGS="$CLINK" >/tmp/m-cu2 2>&1 || true

if [ ! -f src/stdbuf ] || [ ! -f src/libstdbuf.so ]; then
  echo "  ✗ stdbuf 构建失败: $(grep -iE 'error' /tmp/m-cu2 /tmp/m-cu1 2>/dev/null | head -1 | cut -c1-110)"
  exit 0
fi
file src/stdbuf | grep -q 'statically linked' \
  || { echo "  ✗ stdbuf 非全静态: $(file -b src/stdbuf | cut -c1-80)"; exit 0; }

# 4) 落地：主程序走三判据+UPX；.so 只核对 ELF 架构
strip src/stdbuf 2>/dev/null || true
install_verified src/stdbuf stdbuf
em=$(od -An -tx1 -j18 -N1 src/libstdbuf.so | tr -d ' \n')
[ "$em" = "$EM" ] || { echo "  ✗ libstdbuf.so 架构不符（$em ≠ $EM）"; exit 0; }
strip src/libstdbuf.so 2>/dev/null || true
cp src/libstdbuf.so "$OUT/libstdbuf.so" && chmod 755 "$OUT/libstdbuf.so"
printf '  ✓ %-8s %6.2f MB (+libstdbuf.so)\n' libstdbuf.so "$(awk -v s="$(wc -c < "$OUT/libstdbuf.so")" 'BEGIN{print s/1048576}')"
