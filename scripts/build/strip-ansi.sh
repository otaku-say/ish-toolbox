#!/bin/bash
# strip-ansi.sh —— 过滤 ANSI 转义序列，只留纯文本（单文件 C，源随仓库）
# 用途：把带颜色/光标/标题控制的终端输出洗成干净文本，喂给 Agent 或存档。
# 源：./strip-ansi.c（CSI/OSC/DCS/字符集/两字节全兼容状态机，本地编译）
# UPX：7KB 级小工具，实测压不动——交给 UPX 自动跳过（日志显示 "(UPX 跳过)" 即预期行为）。
. "$(dirname "$0")/_common.sh"

SRC="$(cd "$(dirname "$0")" && pwd)/strip-ansi.c"
if $CROSS_CC $CSIZE -Werror=implicit-function-declaration -o /tmp/build/strip-ansi.bin "$SRC" >/tmp/m-strip-ansi 2>&1; then
  install_verified /tmp/build/strip-ansi.bin strip-ansi \
    || echo "  ✗ strip-ansi: 产物验证失败"
else
  echo "  ✗ strip-ansi: $(grep -iE 'error' /tmp/m-strip-ansi 2>/dev/null | head -1 | cut -c1-110)"
fi
