#!/bin/bash
# chronic.sh —— 极简 chronic：命令成功则静默、失败才回放输出（单文件 C，源随仓库）
# 用途：cron / 日检脚本降噪 —— 成功零输出，失败完整保留现场（含退出码透传）。
# 源：./chronic.c（对 moreutils chronic 的最小子集实现，本地编译）
. "$(dirname "$0")/_common.sh"

SRC="$(cd "$(dirname "$0")" && pwd)/chronic.c"
if $CROSS_CC $CSIZE -Werror=implicit-function-declaration -o /tmp/build/chronic.bin "$SRC" >/tmp/m-chronic 2>&1; then
  install_verified /tmp/build/chronic.bin chronic \
    || echo "  ✗ chronic: 产物验证失败"
else
  echo "  ✗ chronic: $(grep -iE 'error' /tmp/m-chronic 2>/dev/null | head -1 | cut -c1-110)"
fi
