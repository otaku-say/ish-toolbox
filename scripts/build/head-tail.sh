#!/bin/bash
# head-tail.sh —— 长日志折叠：头 30 行 + 尾 30 行（单文件 C，源随仓库）
# 用途：给 Agent 看的长日志降噪——60 行以内原样输出，超出折叠中段省 Context Token。
# 源：./head-tail.c（240KB 静态缓冲，零动态分配；本地编译）
# ⚠ 禁用 UPX：arm64 压缩版在 iSH 上 exec 即段错误（qemu 不复现；未压缩版完全正常），
#   2026-10 实测。+6KB 体积换确定性。
. "$(dirname "$0")/_common.sh"
UPX=0

SRC="$(cd "$(dirname "$0")" && pwd)/head-tail.c"
if $CROSS_CC $CSIZE -Werror=implicit-function-declaration -o /tmp/build/head-tail.bin "$SRC" >/tmp/m-head-tail 2>&1; then
  install_verified /tmp/build/head-tail.bin head-tail \
    || echo "  ✗ head-tail: 产物验证失败"
else
  echo "  ✗ head-tail: $(grep -iE 'error' /tmp/m-head-tail 2>/dev/null | head -1 | cut -c1-110)"
fi
