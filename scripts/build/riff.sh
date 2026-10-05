#!/bin/bash
# riff.sh —— diff 着色（Rust，**纯 Rust 依赖无 C**）
#
# 上游虽有 aarch64 预编译二进制（7.2MB），但它是普通 release 构建；
# 自编译配合 opt-level=z + fat LTO + panic=abort 能显著更小，
# 再叠加 UPX 可压到 1MB 级。
. "$(dirname "$0")/_common.sh"

if fetch walles/riff riff; then
  # crate 名是 riffdiff，bin 名是 riff（见其 Cargo.toml 的 [[bin]]）
  ( cd /tmp/build/riff && cargo build --release --target "$T" --bin riff >/tmp/m-riff 2>&1 \
    && cp "target/$T/release/riff" /tmp/build/riff.bin ) \
    && install_verified /tmp/build/riff.bin riff \
    || echo "  ✗ riff: $(grep -iE '^error|could not' /tmp/m-riff 2>/dev/null | head -1 | cut -c1-110)"
fi