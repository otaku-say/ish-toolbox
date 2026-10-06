#!/bin/bash
# strip-ansi.sh —— 过滤 ANSI 转义序列，只留纯文本（单文件 C，源随仓库）
# 用途：把带颜色/光标/标题控制的终端输出洗成干净文本，喂给 Agent 或存档。
# 源：./strip-ansi.c（CSI/OSC/DCS/字符集/两字节全兼容状态机，本地编译）
# UPX 收益≈0（7KB 级小工具，实测根本压不动）：显式禁用，保证各架构产物确定性。
. "$(dirname "$0")/_common.sh"
UPX=0

SRC="$(cd "$(dirname "$0")" && pwd)/strip-ansi.c"
if $CROSS_CC $CSIZE -Werror=implicit-function-declaration -o /tmp/build/strip-ansi.bin "$SRC" >/tmp/m-strip-ansi 2>&1; then
  install_verified /tmp/build/strip-ansi.bin strip-ansi \
    || echo "  ✗ strip-ansi: 产物验证失败"
else
  echo "  ✗ strip-ansi: $(grep -iE 'error' /tmp/m-strip-ansi 2>/dev/null | head -1 | cut -c1-110)"
fi
