#!/bin/bash
# head-tail.sh —— 长日志折叠：头 30 行 + 尾 30 行（单文件 C，源随仓库）
# 用途：给 Agent 看的长日志降噪——60 行以内原样输出，超出折叠中段省 Context Token。
# 源：./head-tail.c（240KB 静态缓冲，零动态分配；本地编译）
# UPX：默认启用。此前"arm64 压缩版段错误"经复验系旧版 UPX(3.96) 的 stub 问题，
#   非本工具代码；4.2.4 压缩版真机验证通过（版本/折叠全正常，2026-10）。
. "$(dirname "$0")/_common.sh"

SRC="$(cd "$(dirname "$0")" && pwd)/head-tail.c"
if $CROSS_CC $CSIZE -Werror=implicit-function-declaration -o /tmp/build/head-tail.bin "$SRC" >/tmp/m-head-tail 2>&1; then
  install_verified /tmp/build/head-tail.bin head-tail \
    || echo "  ✗ head-tail: 产物验证失败"
else
  echo "  ✗ head-tail: $(grep -iE 'error' /tmp/m-head-tail 2>/dev/null | head -1 | cut -c1-110)"
fi
