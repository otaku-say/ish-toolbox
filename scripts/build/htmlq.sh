#!/bin/bash
# htmlq.sh —— HTML CSS 选择器提取（上游 release 只发 x86_64，arm64 需自编）
#
# htmlq 是纯 Rust 项目（html5ever 解析，无 C 依赖），走 jaq 同款
# 「cargo + self-contained 链接」交叉流程；默认分支已停更（0.4.0 是最终版），
# 直接跟随默认分支 = 最新。
. "$(dirname "$0")/_common.sh"

if fetch mgdm/htmlq htmlq; then
  ( cd /tmp/build/htmlq && cargo build --release --target "$T" --bin htmlq >/tmp/m-htmlq 2>&1 \
    && cp "target/$T/release/htmlq" /tmp/build/htmlq.bin ) \
    && install_verified /tmp/build/htmlq.bin htmlq \
    || echo "  ✗ htmlq: $(grep -iE '^error|could not' /tmp/m-htmlq 2>/dev/null | head -1 | cut -c1-110)"
fi
