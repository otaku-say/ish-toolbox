#!/bin/bash
# tini.sh —— 迷你 init（容器级）：转发信号 + 作为 subreaper 收割僵尸进程
# 纯 C、无外部依赖（上游 krallin/tini）。iSH 用途：守候/后台进程的信号转发与收尸。
#
# ⚙ iSH 适配补丁 tini-fix.patch（随本脚本同目录，针对 v0.19.0）：
#   1) 信号层：上游 block+sigtimedwait 在 iSH 上失效（pending 信号永不投递：
#      TERM 收不到、不转发、进程无法被正常终止）→ 改为 handler 置标志 +
#      主循环 100ms tick 轮询转发（Linux 行为等价；已过 23 项套件 + 三信号转发）
#   2) register_subreaper：PR_SET_CHILD_SUBREAPER 不可用时 FATAL → WARN 继续
#      （iSH 无此 prctl；与"非 PID1 未注册 subreaper"的既有告警语义一致）
#   3) 高编号实时信号不支持时跳过（iSH 上限 63）+ 补 libgen.h（zig 头缺 basename）
#   注：tiniConfig.h 是 CMake 产物，这里生成最小等价物；HAS_SUBREAPER 内核头自动检测。
#   上游升级时需 rebase 该补丁。
# 上游：krallin/tini（tag 为 v 前缀）
. "$(dirname "$0")/_common.sh"

VER=0.19.0   # 锁定：补丁针对此版本；升级须先 rebase tini-fix.patch
PATCH="$(cd "$(dirname "$0")" && pwd)/tini-fix.patch"
echo "  tini 上游: v$VER（+ iSH 信号修复补丁）"

if fetch_url "https://github.com/krallin/tini/archive/refs/tags/v$VER.tar.gz" "tini-$VER" tini; then
  ( cd /tmp/build/tini \
    && patch -p1 < "$PATCH" >/tmp/m-tini 2>&1 \
    && printf '#define TINI_VERSION "v%s"\n#define TINI_GIT ""\n' "$VER" > src/tiniConfig.h \
    && $CROSS_CC $CSIZE -Werror=implicit-function-declaration -o /tmp/build/tini.bin src/tini.c >>/tmp/m-tini 2>&1 ) \
    && install_verified /tmp/build/tini.bin tini \
    || echo "  ✗ tini: $(grep -iE '^error|could not|FAILED|Reversed|Hunk' /tmp/m-tini 2>/dev/null | head -1 | cut -c1-110)"
fi
