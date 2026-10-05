#!/bin/bash
# faketty.sh —— 把命令放进伪终端（PTY）里跑 → 替代 stdbuf
#
# 与 stdbuf 的关键差别：stdbuf 靠 LD_PRELOAD 注入（只对动态进程有效），
# faketty 用 PTY 让任何程序（含静态二进制）自认 stdout/stderr 是终端 →
# 自动行缓冲/彩色输出。iSH 工具箱全是静态二进制，PTY 方案才是治本解。
# 行为契约（上游+补丁测试为准）：stdin=原样、stdout/stderr=各自独立 PTY、
# 退出码透传、输出按终端语义（含 \r\n）。
#
# ⚙ iSH 适配补丁 faketty-fix.patch（与本脚本同目录）：
#   iSH 的 pty 主端在 slave 全关后不发 EOF/EIO，上游版 copyfd 阻塞 read 永不返回
#   → 子进程退出后 faketty 挂死并泄漏进程。补丁改为 poll(100ms) 轮询 +
#   waitpid(WNOHANG) 收尾（退出码逐层传递）。已在 iSH aarch64 与 Ubuntu x86_64
#   双环境 9/9 验证。
#   ⚠ 源必须取 crates.io 规范包：补丁针对其规范化 Cargo.toml 生成；
#     GitHub tarball 是 inline 格式且 nix 版本不同，补丁打不上。
# 上游：dtolnay/faketty（tag 无 v 前缀；纯 Rust + nix FFI，无 C 依赖）
. "$(dirname "$0")/_common.sh"

VER=1.0.20   # 锁定：补丁针对此版本；上游升级时须先 rebase faketty-fix.patch
PATCH="$(cd "$(dirname "$0")" && pwd)/faketty-fix.patch"
echo "  faketty 上游: $VER（+ iSH 修复补丁）"

if fetch_url "https://static.crates.io/crates/faketty/faketty-$VER.crate" "faketty-$VER" faketty; then
  ( cd /tmp/build/faketty \
    && patch -p1 < "$PATCH" >/tmp/m-faketty 2>&1 \
    && cargo build --release --target "$T" >>/tmp/m-faketty 2>&1 \
    && cp "target/$T/release/faketty" /tmp/build/faketty.bin ) \
    && install_verified /tmp/build/faketty.bin faketty \
    || echo "  ✗ faketty: $(grep -iE '^error|could not|FAILED|Reversed' /tmp/m-faketty 2>/dev/null | head -1 | cut -c1-110)"
fi
