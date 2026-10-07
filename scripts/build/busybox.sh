#!/bin/bash
# busybox.sh —— BusyBox 全静态单文件（defconfig 全量 applet；每日自动跟最新版本）
#
# 配方要点（2026-10·沙箱预演 + CI 双架构验证）：
#   ① 上游只发源码 tarball（busybox.net），无预编译二进制 → 自编译
#   ② kconfig 构建系统：make defconfig + CONFIG_STATIC=y → 全静态
#   ③ 两架构统一 GNU GCC + musl 静态（对称构建）：
#      amd64 = musl-gcc（Ubuntu musl-tools，底层 GNU GCC，CC 显式传入）
#      arm64 = aarch64-linux-gcc（Bootlin aarch64--musl 交叉链 GCC 12，
#              CROSS_COMPILE 机制全交叉；CI 由 workflow 安装到 /opt/musl-a64
#              并入 PATH，musl.cc 为备用来源）
#   ④ amd64 特有：musl sysroot 不含内核 UAPI 头（linux/kd.h 等）→ 拷贝
#      UAPI 头到 /tmp/bb-kheaders，wrapper 以 -idirafter 注入（无 root、
#      不污染搜索顺序）。arm64 的 Bootlin sysroot 自带完整 UAPI，无需处理。
#   ⑤ HOSTCC 保持宿主 gcc（编译 fixdep 等构建期工具）
#   ⑥ SKIP_STRIP=y：统一交 install_verified 做 strip（_common.sh 已按目标
#      架构选 aarch64-linux-gnu-strip，跨架构 strip 实测有效）
#   ⑦ SOURCE_DATE_EPOCH 固定 → AUTOCONF_TIMESTAMP 确定性（busybox kconfig
#      原生支持；保证上游无变化时每日重建产物一致，不产生无谓提交）
#   ⑧ 版本号动态取自官方 downloads 列表（每日 schedule 自动跟新版）
. "$(dirname "$0")/_common.sh"

# ── 动态查最新版本（失败/异常回退默认）─────────────────────────
BVER=$(latest_from_listing "https://busybox.net/downloads/" \
         'busybox-[0-9]+\.[0-9]+\.[0-9]+\.tar\.bz2')
BVER=${BVER#busybox-}; BVER=${BVER%.tar.bz2}
echo "$BVER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || BVER=1.38.0
echo "  · busybox 目标版本：$BVER"

# ── 下载源码（官方 + Buildroot 镜像回退）───────────────────────
BB_OK=""
for U in "https://busybox.net/downloads/busybox-$BVER.tar.bz2" \
         "https://sources.buildroot.net/busybox/busybox-$BVER.tar.bz2"; do
  if fetch_url "$U" "busybox-$BVER" busyboxsrc; then BB_OK=1; break; fi
done
[ -z "$BB_OK" ] && { echo "  ✗ busybox: 下载失败（两源均不可达）"; exit 0; }

# ── 工具链与编译参数（两架构均为 GNU GCC + musl 静态）──────────
if [ "$ARCH" = arm64 ]; then
  # arm64：Bootlin/musl.cc 交叉链（GCC 12）；CROSS_COMPILE 机制全套交叉
  gnu_arm64_cc || { echo "  ✗ busybox: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 0; }
  MK="CROSS_COMPILE=aarch64-linux-"
else
  # amd64：musl-gcc（GNU GCC）+ 内核 UAPI 头 wrapper（musl sysroot 缺 linux/*.h）
  KH=/tmp/bb-kheaders
  if [ ! -e "$KH/linux/kd.h" ]; then
    mkdir -p "$KH"
    for d in linux asm-generic mtd sound rdma drm xen; do cp -r "/usr/include/$d" "$KH/" 2>/dev/null; done
    cp -r /usr/include/x86_64-linux-gnu/asm "$KH/asm" 2>/dev/null
  fi
  printf '#!/bin/sh\nexec %s -idirafter %s "$@"\n' "$CROSS_CC" "$KH" > /tmp/bb-cc
  chmod +x /tmp/bb-cc
  MK="CC=/tmp/bb-cc"
fi

# ── 配置 + 编译（SOURCE_DATE_EPOCH 固定保证产物确定性）────────
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1700000000}"
( cd /tmp/build/busyboxsrc \
  && make defconfig >/tmp/c-bb 2>&1 \
  && sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config \
  && grep -q '^CONFIG_STATIC=y' .config \
  && { make -j"$(nproc)" SKIP_STRIP=y $MK >/tmp/m-bb 2>&1 \
       || { echo "  ! 构建首轮失败，增量重试一次"; \
            make -j"$(nproc)" SKIP_STRIP=y $MK >/tmp/m-bb 2>&1; }; } \
  && cp busybox /tmp/build/busybox.bin ) \
  && install_verified /tmp/build/busybox.bin busybox \
  || echo "  ✗ busybox: $(grep -iE 'error|not found' /tmp/m-bb /tmp/c-bb 2>/dev/null | head -1 | cut -c1-110)"
