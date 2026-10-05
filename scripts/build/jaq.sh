#!/bin/bash
# jaq.sh —— jq 的 Rust 快速实现（自编译；上游 arm64 只有 glibc 产物，musl 需自编）
#
# 上游：01mf02/jaq（取 GitHub latest release 的 tag 源码包；失败回落 v3.1.1）
# arm64 用 --no-default-features 避开 mimalloc 的 C 依赖
#   （Zig 编 libmimalloc-sys 失败；纯 Rust 分配器零 C 依赖 —— 历史踩坑记录）
# 与 gojq 的分工（二选一结论见 SKILL.md）：jaq 快、现代；
#   gojq 保留为默认（模块系统 + 大整数无损），jaq 定位高性能补充。
. "$(dirname "$0")/_common.sh"

AUTH=""; [ -n "${GITHUB_TOKEN:-}" ] && AUTH="Authorization: Bearer ${GITHUB_TOKEN}"
VER=$(curl -fsSL --max-time 30 ${AUTH:+-H "$AUTH"} \
      "https://api.github.com/repos/01mf02/jaq/releases/latest" 2>/dev/null \
      | grep -oE '"tag_name": *"[^"]+"' | head -1 | cut -d'"' -f4)
[ -z "$VER" ] && VER=v3.1.1
echo "  jaq 上游: $VER"

NUM="${VER#v}"
if fetch_url "https://github.com/01mf02/jaq/archive/refs/tags/$VER.tar.gz" "jaq-$NUM" jaq; then
  if [ "$ARCH" = arm64 ]; then JF="--no-default-features"; else JF=""; fi
  ( cd /tmp/build/jaq \
    && cargo build --release --target "$T" -p jaq --bin jaq $JF >/tmp/m-jaq 2>&1 \
    && cp "target/$T/release/jaq" /tmp/build/jaq.bin ) \
    && install_verified /tmp/build/jaq.bin jaq \
    || echo "  ✗ jaq: $(grep -iE '^error|could not' /tmp/m-jaq 2>/dev/null | head -1 | cut -c1-110)"
fi
