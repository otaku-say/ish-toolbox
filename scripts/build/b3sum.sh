#!/bin/bash
# b3sum.sh —— BLAKE3 官方 Rust 实现（上游**不发布 arm64 二进制**，只能自编）
#
# 上游最新：GitHub 默认分支
# 注意：b3sum crate 的特性是 neon / prefer_intrinsics / pure —— **没有 std**
#       （按 blake3 库的特性名写 `--features std,pure` 会被 cargo 直接拒绝）
# arm64 用 pure 模式：Zig 作为 CC 编 C 加速部分会失败，纯 Rust 路径最稳。
. "$(dirname "$0")/_common.sh"

if fetch BLAKE3-team/BLAKE3 BLAKE3; then
  if [ "$ARCH" = arm64 ]; then B3F="--features pure"; else B3F=""; fi
  # b3sum 是独立 crate（仓库根目录是 [package] blake3，不是 workspace）
  ( cd /tmp/build/BLAKE3/b3sum && cargo build --release --target "$T" $B3F >/tmp/m-b3sum 2>&1 \
    && cp "target/$T/release/b3sum" /tmp/build/b3sum.bin ) \
    && install_verified /tmp/build/b3sum.bin b3sum \
    || echo "  ✗ b3sum: $(grep -iE '^error|could not|does not contain' /tmp/m-b3sum 2>/dev/null | head -1 | cut -c1-110)"
fi