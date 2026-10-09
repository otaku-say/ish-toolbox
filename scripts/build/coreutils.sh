#!/bin/bash
# coreutils.sh —— GNU Coreutils 9.12 官方多路复用版（单文件 · 全静态）
#
# 要点（2026-10·沙箱双架构实测）：
#   ① --enable-single-binary：全部程序编入单一 coreutils 二进制；
#      分发 = argv[0]（软链名）或 --coreutils-prog=NAME
#      （symlinks/hardlinks/shebangs 只是 make install 的安装形态，对二进制本体无影响）
#   ② 静态精简：--disable-nls/acl/xattr/libcap --without-selinux（musl 静态不拖外部库）
#   ③ amd64（musl-gcc）sysroot 缺内核 UAPI 头：lib/copy-file-range.c 需要 linux/version.h，
#      拷贝宿主 UAPI 头并用 -idirafter 注入（与 busybox.sh 同法；arm64 Bootlin sysroot 自带）
#   ④ root 构建需 FORCE_UNSAFE_CONFIGURE=1（configure 防呆；CI runner 非 root 亦兼容）
#   ⑤ SOURCE_DATE_EPOCH 固定：上游无变化时每日重建产物一致，不产生无谓提交
#   ⑥ 临时文件名必须为 coreutils（不得加 .bin 后缀）：install_verified 的 UPX 后运行自检
#      按 argv[0] 判定，多路复用分发器要求程序名不以 coreutils 结尾即报 unknown program
#      ——曾因此把 amd64 的 UPX 误判为"跑不起来"而回退（实为文件名问题）
. "$(dirname "$0")/_common.sh"

# 版本：默认自动跟随上游最新稳定版；可用 COREUTILS_VERSION 显式指定；解析失败回退已知良好版
CVER="${COREUTILS_VERSION:-}"
[ -z "$CVER" ] && { CVER=$(latest_gnu coreutils 'coreutils-[0-9]+\.[0-9]+\.tar\.xz'); CVER=${CVER#coreutils-}; CVER=${CVER%.tar.xz}; }
echo "$CVER" | grep -qE '^[0-9]+\.[0-9]+$' || CVER=9.12
echo "  · coreutils 目标版本：$CVER"

if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ coreutils: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 0; }
fi

# 保证源码树全新：同机连跑两架构时，上一架构的残留对象会混入下一架构（2026-10 实证：
# 5 个 x86-64 残留 .o 混入 arm64 归档导致链接失败）；CI 每腿全新环境本无此问题
rm -rf /tmp/build/cusrc
fetch_gnu "coreutils/coreutils-$CVER.tar.xz" "coreutils-$CVER" cusrc \
  || { echo "  ✗ coreutils: 下载失败（_common 镜像链均不可达）"; exit 0; }

# ── amd64：musl sysroot 缺 linux/*.h UAPI 头（copy-file-range.c 等需要）──
CCV="$CROSS_CC"
if [ "$ARCH" = amd64 ]; then
  KH=/tmp/cu-kheaders
  if [ ! -e "$KH/linux/version.h" ]; then
    mkdir -p "$KH"
    for d in linux asm-generic mtd sound rdma drm xen; do cp -r "/usr/include/$d" "$KH/" 2>/dev/null; done
    cp -r /usr/include/x86_64-linux-gnu/asm "$KH/asm" 2>/dev/null
  fi
  printf '#!/bin/sh\nexec %s -idirafter %s "$@"\n' "$CROSS_CC" "$KH" > /tmp/cu-cc
  chmod +x /tmp/cu-cc
  CCV=/tmp/cu-cc
fi

export FORCE_UNSAFE_CONFIGURE=1
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1700000000}"
( cd /tmp/build/cusrc \
  && CC="$CCV" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
     ./configure --host="$T" \
         --disable-nls --disable-acl --disable-xattr --disable-libcap --without-selinux \
         --enable-single-binary >/tmp/c-cu 2>&1 \
  && make -j"$(nproc)" >/tmp/m-cu 2>&1 \
  && cp src/coreutils /tmp/build/coreutils ) \
  && install_verified /tmp/build/coreutils coreutils \
  || echo "  ✗ coreutils: $(grep -iE 'error' /tmp/m-cu /tmp/c-cu 2>/dev/null | head -1 | cut -c1-110)"
