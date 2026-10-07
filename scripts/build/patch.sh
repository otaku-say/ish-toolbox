#!/bin/bash
# patch.sh —— GNU patch（C，autotools）
#
# 上游最新：GNU 官方目录（自带 configure，不用 GitHub 镜像的 autoreconf 路线）。
# ⚠ ftp.gnu.org / ftpmirror 在 CI 侧不可达（2026-10 探针实锤）→ 走 _common 的
# 统一镜像链（kernel.org / 清华 / 阿里 / 官方兜底）。
. "$(dirname "$0")/_common.sh"

# ── arm64：必须完整 GNU 交叉链（Bootlin aarch64--musl；CI 由 workflow 安装）──
if [ "$ARCH" = arm64 ]; then
  gnu_arm64_cc || { echo "  ✗ patch: 缺 aarch64-linux-gcc（GNU musl 交叉链未安装）"; exit 0; }
fi

VER=$(latest_gnu patch 'patch-[0-9]+\.[0-9]+\.tar\.gz' || true)
[ -z "$VER" ] && { echo "  ! patch 版本查询失败"; exit 0; }
echo "  patch 上游最新: $VER"

if fetch_gnu "patch/$VER" "${VER%.tar.gz}" patch; then
  ( cd /tmp/build/patch \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
       ./configure --host="$T" --disable-dependency-tracking >/tmp/c-patch 2>&1 \
    && make -j"$(nproc)" >/tmp/m-patch 2>&1 && cp src/patch /tmp/build/patch.bin ) \
    && install_verified /tmp/build/patch.bin patch \
    || echo "  ✗ patch: $(grep -iE 'error|not found' /tmp/m-patch /tmp/c-patch 2>/dev/null | head -1 | cut -c1-110)"
fi
