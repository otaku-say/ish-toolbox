#!/bin/bash
# build-from-source-ci.sh —— 编排器：逐个调用 scripts/build/<tool>.sh
#
# 每个工具一个独立脚本（可单独跑、单独调试），本脚本只负责：
#   1. 设置公共环境（Rust 工具链、Zig、apt 依赖）
#   2. 依次调用各工具脚本
#   3. 汇总结果并更新 SHA256SUMS
#
# 环境变量 ARCH=arm64|amd64 由 workflow 的矩阵提供。
set -uo pipefail

ARCH="${ARCH:?需要 ARCH=arm64|amd64}"
export ARCH
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$HERE")"          # 仓库根目录（OUT 路径相对于它）
mkdir -p "tools/$ARCH"

# ── 公共环境 ─────────────────────────────────────────────────
export CARGO_HOME="$HOME/.cargo" RUSTUP_HOME="$HOME/.rustup"
[ -f "$CARGO_HOME/env" ] && . "$CARGO_HOME/env"
command -v cargo >/dev/null || { echo "✗ cargo 不在 PATH"; exit 1; }
echo "cargo: $(cargo --version)"

case "$ARCH" in
  arm64) rustup target add aarch64-unknown-linux-musl 2>/dev/null ;;
  amd64) rustup target add x86_64-unknown-linux-musl 2>/dev/null ;;
esac

# ── 逐工具构建（每个都是独立进程，失败不影响其它）──────────────
# 现役：patch（上游不给 arm64 musl 产物）、micropython/tree/sqlite3（上游只发源码）
TOOLS="patch micropython tree sqlite3"
ok=0; failed=""
for t in $TOOLS; do
  echo "───────── $t ─────────"
  if bash "$HERE/build/$t.sh"; then
    # 判定该工具是否真的产出了文件（脚本本身总是 exit 0）
    if [ -f "tools/$ARCH/$t" ]; then ok=$((ok+1)); else failed="$failed $t"; fi
  else
    failed="$failed $t"
  fi
done

( cd "tools/$ARCH" && sha256sum * > SHA256SUMS 2>/dev/null )

echo
echo "═══ $ARCH 完成：成功 $ok 个，失败:${failed:- 无} ═══"
ls -l "tools/$ARCH" | awk 'NR>1{printf "  %-10s %8.2f MB\n", $9, $5/1048576}'
# ⚠️ 必须无条件 exit 0：部分工具失败不应阻断"提交已成功产物"这一步。
# （曾经写成 `[ $fail -gt 0 ] && exit 0`，全部成功时该行返回 1 → job failure
#   → 后续 commit 步骤被跳过，编好的产物全部白费）
exit 0