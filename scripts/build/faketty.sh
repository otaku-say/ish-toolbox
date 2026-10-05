#!/bin/bash
# faketty.sh —— 把命令放进伪终端（PTY）里跑 → 替代 stdbuf
#
# 与 stdbuf 的关键差别：stdbuf 靠 LD_PRELOAD 注入（只对动态进程有效），
# faketty 用 PTY 让任何程序（含静态二进制）自认 stdout/stderr 是终端 →
# 自动行缓冲/彩色输出。iSH 工具箱全是静态二进制，PTY 方案才是治本解。
# 行为契约（上游测试为准）：stdin=原样、stdout/stderr=各自独立 PTY、
# 退出码透传、输出按终端语义（含 \r\n）。
# 上游：dtolnay/faketty（tag 无 v 前缀；纯 Rust + nix FFI，无 C 依赖）
. "$(dirname "$0")/_common.sh"

AUTH=""; [ -n "${GITHUB_TOKEN:-}" ] && AUTH="Authorization: Bearer ${GITHUB_TOKEN}"
VER=$(curl -fsSL --max-time 30 ${AUTH:+-H "$AUTH"} \
      "https://api.github.com/repos/dtolnay/faketty/releases/latest" 2>/dev/null \
      | grep -oE '"tag_name": *"[^"]+"' | head -1 | cut -d'"' -f4)
[ -z "$VER" ] && VER=1.0.20
echo "  faketty 上游: $VER"

if fetch_url "https://github.com/dtolnay/faketty/archive/refs/tags/$VER.tar.gz" "faketty-$VER" faketty; then
  ( cd /tmp/build/faketty \
    && cargo build --release --target "$T" >/tmp/m-faketty 2>&1 \
    && cp "target/$T/release/faketty" /tmp/build/faketty.bin ) \
    && install_verified /tmp/build/faketty.bin faketty \
    || echo "  ✗ faketty: $(grep -iE '^error|could not' /tmp/m-faketty 2>/dev/null | head -1 | cut -c1-110)"
fi
