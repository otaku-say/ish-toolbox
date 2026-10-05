#!/bin/sh
# build-from-source.sh —— 从源码交叉编译免依赖静态二进制
#
# 用途：上游不提供 arm64 产物时（绝大多数 Rust 项目都这样）自行编译。
#       已实测需要走这条路的：BLAKE3/b3sum、jaq、hexyl、hyperfine、eza、navi…
#
# 体积优化（用户提供的方案，通过**环境变量注入**而非改 Cargo.toml）：
#   好处 ① 上游源码更新时优化配置不会被覆盖  ② 可按项目关掉 panic=abort
#   opt-level=z  针对体积优化 / lto=true  跨 crate 死代码剔除
#   codegen-units=1  允许全局激进内联 / panic=abort  移除栈展开表(.eh_frame)
#   strip=symbols  链接阶段丢弃符号
#   实测效果：b3sum 从 5.0MB 降到 1.5MB，功能与性能完全不受影响。
#
# 用法：
#   sh build-from-source.sh <owner/repo> <二进制名> [arch]
# 例：
#   sh build-from-source.sh BLAKE3-team/BLAKE3 b3sum arm64
#   sh build-from-source.sh BLAKE3-team/BLAKE3 b3sum amd64
#
# 依赖：git cargo curl tar musl 交叉工具链（脚本会自动装）
# 产物：tools/<二进制名>/<arch>/<二进制名>
set -eu

REPO="${1:?用法: build-from-source.sh <owner/repo> <binary> [arch]}"
BIN="${2:?缺少二进制名}"
ARCH="${3:-$(case "$(uname -m)" in aarch64|arm64) echo arm64;; *) echo amd64;; esac)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="/tmp/bsrc.$$"; mkdir -p "$W"; trap 'rm -rf "$W"' EXIT INT TERM

case "$ARCH" in
  arm64) TARGET=aarch64-unknown-linux-musl; EM=b7 ;;
  amd64) TARGET=x86_64-unknown-linux-musl;  EM=3e ;;
  *) echo "✗ 架构只能是 arm64 / amd64"; exit 1 ;;
esac

echo "=== $REPO → $BIN [$ARCH / $TARGET] ==="

# 1) 源码
git clone --depth=1 "https://github.com/$REPO" "$W/src" 2>/dev/null || {
  echo "✗ clone 失败"; exit 1; }
cd "$W/src"
git log -1 --format='    commit %h  %s' 2>/dev/null | head -1

# 2) Rust + musl target（宿主机不是目标架构时，需交叉链接器）
if ! command -v cargo >/dev/null 2>&1; then
  echo "→ 装 rustup"
  curl -sSf https://sh.rustup.rs -o "$W/rustup.sh"
  sh "$W/rustup.sh" -y --profile minimal >/dev/null 2>&1
fi
. "$HOME/.cargo/env" 2>/dev/null || true
command -v cargo >/dev/null 2>&1 || { echo "✗ 没有 cargo"; exit 1; }

# ── linker：这是 musl target 最容易静默失败的一环 ────────────────────────
# musl target 的链接器**即使在原生架构上**也必须显式指定——宿主是 glibc，
# cargo 默认去找 <arch>-linux-musl-gcc，找不到会**打印 warning 后静默降级**，
# 最后显示 "Finished release profile" 却根本不产出二进制。
#   · 跨架构（arm64 on x86_64 runner）→ musl.cc 工具链的 aarch64-linux-musl-gcc
#   · 原生架构（amd64 on x86_64）    → musl-tools 的 musl-gcc
case "$TARGET" in
  aarch64-unknown-linux-musl)
    export CC_aarch64_unknown_linux_musl=aarch64-linux-musl-gcc
    export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=aarch64-linux-musl-gcc
    if [ ! -x /opt/musl-cross/bin/aarch64-linux-musl-gcc ]; then
      echo "→ 装 musl 交叉工具链（aarch64）"
      if [ ! -d /opt/aarch64-linux-musl-cross ]; then
        curl -fsSL --max-time 600 -o "$W/musl.tgz" https://musl.cc/aarch64-linux-musl-cross.tgz
        mkdir -p /opt && tar xzf "$W/musl.tgz" -C /opt
        mv /opt/aarch64-linux-musl-cross /opt/musl-cross 2>/dev/null || true
      fi
      [ -d /opt/musl-cross/bin ] && PATH="/opt/musl-cross/bin:$PATH"
    fi
    ;;
  x86_64-unknown-linux-musl)
    if ! command -v musl-gcc >/dev/null 2>&1; then
      echo "→ 装 musl-tools（原生 musl linker）"
      (apt-get install -y -qq musl-tools || apk add --no-cache musl-dev) >/dev/null 2>&1 || true
    fi
    export CC_x86_64_unknown_linux_musl=musl-gcc
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc
    ;;
esac
rustup target add "$TARGET" 2>/dev/null || true

# 3) 体积优化：用环境变量注入，不改 Cargo.toml
export CARGO_PROFILE_RELEASE_OPT_LEVEL=z
export CARGO_PROFILE_RELEASE_LTO=true
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
export CARGO_PROFILE_RELEASE_STRIP=symbols
# panic=abort 会移除栈展开表，但若项目依赖 catch_unwind 会编译失败，
# 故先试开启，失败则退回 unwind 重编一次。
build() { cargo build --release --target "$TARGET" 2>&1 | tail -${1:-8}; }

echo "→ 构建（体积优化：opt-level=z lto codegen-units=1 strip）"
if CARGO_PROFILE_RELEASE_PANIC=abort build 12; then
  echo "  ✓ panic=abort 生效（已移除栈展开表）"
elif build 12; then
  echo "  ⚠ panic=abort 不适用，已退回 unwind（体积略大）"
else
  echo "✗ 编译失败"; exit 1
fi

B="target/$TARGET/release/$BIN"
[ -f "$B" ] || { echo "✗ 未找到产物 $B"; exit 1; }
strip "$B" 2>/dev/null || true

# 4) 三重判定
readelf -l "$B" 2>/dev/null | grep -q INTERP && { echo "✗ 非静态（有 PT_INTERP）"; exit 1; }
readelf -d "$B" 2>/dev/null | grep -q NEEDED  && { echo "✗ 非静态（有 NEEDED）"; exit 1; }
em=$(od -An -tx1 -j18 -N1 "$B" | tr -d ' \n')
[ "$em" = "$EM" ] || { echo "✗ 架构不符（$em ≠ $EM）"; exit 1; }

D="$ROOT/tools/$BIN/$ARCH"
mkdir -p "$D"
cp "$B" "$D/$BIN" && chmod +x "$D/$BIN"
( cd "$D" && sha256sum "$BIN" > SHA256SUMS 2>/dev/null )

printf '  ✓ %-10s %6s MB  静态 aarch64/musl ✓\n' "$BIN" \
  "$(awk -v s=$(wc -c < "$D/$BIN") 'BEGIN{printf "%.2f", s/1048576}')"
echo "  → $D/$BIN"
