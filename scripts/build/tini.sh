#!/bin/bash
# tini.sh —— 迷你 init（容器级）：转发信号 + 作为 subreaper 收割僵尸进程
# 纯 C、无外部依赖（上游 krallin/tini）。iSH 用途：守候/后台进程的信号转发与收尸。
# 注1：tiniConfig.h 是 CMake 产物，这里直接生成最小等价物（TINI_VERSION/TINI_GIT）；
#     HAS_SUBREAPER 由 tini.c 依据内核头自动检测，无需配置。
# 注2：构建时补插 #include <libgen.h> —— basename 声明在 glibc/musl-dev 的 string.h 里有，
#     但 zig 自带的 musl 头没有 → 不补会以隐式声明编出坏二进制（或直接报错）。
. "$(dirname "$0")/_common.sh"

VER=0.19.0   # 上游 tag 为 v0.19.0（GitHub 打包目录名去 v 前缀）
if fetch_url "https://github.com/krallin/tini/archive/refs/tags/v$VER.tar.gz" "tini-$VER" tini; then
  ( cd /tmp/build/tini \
    && printf '#define TINI_VERSION "v%s"\n#define TINI_GIT ""\n' "$VER" > src/tiniConfig.h \
    && grep -q 'include <libgen.h>' src/tini.c || sed -i 's|#include <unistd.h>|#include <unistd.h>\n#include <libgen.h>  /* 补 basename 声明：zig 自带 musl 头未在 string.h 暴露 */|' src/tini.c \
    && $CROSS_CC $CSIZE -Werror=implicit-function-declaration -o /tmp/build/tini.bin src/tini.c ) >/tmp/m-tini 2>&1 \
    && install_verified /tmp/build/tini.bin tini \
    || echo "  ✗ tini: $(grep -iE 'error' /tmp/m-tini 2>/dev/null | head -1 | cut -c1-110)"
fi
