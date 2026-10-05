#!/bin/bash
# jaq.sh —— Rust 版 jq（上游 arm64 只有 gnu 版，musl 需自编）
#
# 上游最新：GitHub 默认分支
# arm64 用 --no-default-features 避开 libmimalloc-sys 的 C 依赖
# （Zig 作为 CC 编它失败；纯 Rust 分配器没有任何 C 依赖）
. "$(dirname "$0")/_common.sh"

if fetch 01mf02/jaq jaq; then
  if [ "$ARCH" = arm64 ]; then JF="--no-default-features"; else JF=""; fi
  ( cd /tmp/build/jaq && cargo build --release --target "$T" --bin jaq $JF >/tmp/m-jaq 2>&1 \
    && cp "target/$T/release/jaq" /tmp/build/jaq.bin ) \
    && install_verified /tmp/build/jaq.bin jaq \
    || echo "  ✗ jaq: $(grep -iE '^error|could not' /tmp/m-jaq 2>/dev/null | head -1 | cut -c1-110)"
fi