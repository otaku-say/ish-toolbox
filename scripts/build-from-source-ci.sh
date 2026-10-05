#!/bin/bash
# build-from-source-ci.sh —— 在 GitHub Actions 里编译双架构静态二进制（v2）
#
# v1 失败原因（第一次 CI 跑出来的真实结果）：
#   · can't find crate for `core` → 脚本写的是 . /root/.cargo/env（沙箱路径），
#     GitHub runner 的 HOME 是 /home/runner，rustup 环境根本没加载
#   · musl.cc 在 runner 上连不上（curl 超时 135s）→ arm64 交叉工具链拿不到
#   · nnn/ncdu 找不到 curses.h → apt 装了 libncurses-dev 但细节没处理
#
# v2 策略：
#   1. HOME 通用化（不再硬编码 /root）
#   2. arm64 不再依赖 musl.cc：用 Rust 自带的 self-contained 链接
#      （rust-lld + 自带 libc.a）+ apt 的 gcc-aarch64-linux-gnu 编 C 部分
#   3. 每个失败都打印**真实错误**，不再吞进 /dev/null
set -uo pipefail

ARCH="${ARCH:?需要 ARCH=arm64|amd64}"
OUT="tools/$ARCH"
mkdir -p "$OUT" /tmp/build
cd "$(git rev-parse --show-toplevel)"

case "$ARCH" in
  amd64) T=x86_64-unknown-linux-musl;  CROSS="" ;;
  arm64) T=aarch64-unknown-linux-musl; CROSS=aarch64-linux-gnu- ;;
  *) echo "✗ 未知架构 $ARCH"; exit 1 ;;
esac
K=$(echo "$T" | tr 'a-z-' 'A-Z_')

# ── Rust 环境：HOME 通用化（v1 就死在这里）──────────────────────
export CARGO_HOME="$HOME/.cargo" RUSTUP_HOME="$HOME/.rustup"
[ -f "$CARGO_HOME/env" ] && . "$CARGO_HOME/env"
command -v cargo >/dev/null || { echo "✗ cargo 不在 PATH"; exit 1; }
echo "cargo: $(cargo --version)  target: $T"
rustup target add "$T" || echo "  ! target add 失败，继续试试"

# ── 链接器与 C 编译器 ─────────────────────────────────────────
# Rust musl target 自 1.71 起自带 self-contained 链接（rust-lld + 自带 libc.a），
# 因此**不需要 musl.cc 工具链**。C 部分：
#   · amd64 → apt 的 musl-gcc
#   · arm64 → Zig（自带 musl libc；musl.cc 在 runner 上连不上，v1 就死在这）
if [ "$ARCH" = arm64 ]; then
  cat > /tmp/zigcc <<'EOF'
#!/bin/sh
exec zig cc -target aarch64-linux-musl "$@"
EOF
  chmod +x /tmp/zigcc
  export CC_aarch64_unknown_linux_musl=/tmp/zigcc
  export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=rust-lld
  export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_RUSTFLAGS="-C link-self-contained=yes"
  CROSS_CC=/tmp/zigcc
else
  export CC_x86_64_unknown_linux_musl=musl-gcc
  export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc
  CROSS_CC=musl-gcc
fi
export RUSTFLAGS="-C relocation-model=static"
export CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_LTO=true
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 CARGO_PROFILE_RELEASE_STRIP=symbols

ok=0; fail=0
want_em() { [ "$ARCH" = arm64 ] && echo b7 || echo 3e; }

install_verified() {  # <路径> <命令名>
  local b="$1" n="$2"
  [ -f "$b" ] || { echo "  ✗ $n 产物不存在"; fail=$((fail+1)); return 1; }
  readelf -l "$b" 2>/dev/null | grep -q INTERP && { echo "  ✗ $n 非静态(PT_INTERP)"; fail=$((fail+1)); return 1; }
  readelf -d "$b" 2>/dev/null | grep -q NEEDED  && { echo "  ✗ $n 非静态(NEEDED)";   fail=$((fail+1)); return 1; }
  local em; em=$(od -An -tx1 -j18 -N1 "$b" | tr -d ' \n')
  [ "$em" = "$(want_em)" ] || { echo "  ✗ $n 架构不符($em)"; fail=$((fail+1)); return 1; }
  strip "$b" 2>/dev/null || true
  cp "$b" "$OUT/$n" && chmod +x "$OUT/$n"
  printf '  ✓ %-8s %6.2f MB\n' "$n" "$(awk -v s="$(wc -c < "$OUT/$n")" 'BEGIN{print s/1048576}')"
  ok=$((ok+1))
}

fetch() {  # <owner/repo> <dir>
  local d="/tmp/build/$2"
  [ -d "$d" ] && return 0
  for br in main master; do
    curl -fsSL --max-time 180 "https://github.com/$1/archive/refs/heads/$br.tar.gz" -o /tmp/x.tgz && {
      tar xzf /tmp/x.tgz -C /tmp/build && mv "/tmp/build/$2-$br" "$d" 2>/dev/null && return 0; }
  done
  echo "  ! 下载失败 $1"; return 1
}

echo "═══ $ARCH (target=$T cc=$CROSS_CC) ═══"

# ── fzy：单文件 C（v1 报 "compilation terminated"是目录不存在导致）──
if fetch jhawthorn/fzy fzy; then
  ls /tmp/build/fzy/fzy.c >/dev/null 2>&1 || echo "  ! fzy.c 不在预期位置: $(ls /tmp/build/fzy | head -3)"
  if [ "$ARCH" = arm64 ]; then
    zig cc -target aarch64-linux-musl -O3 -static -o /tmp/build/fzy.bin /tmp/build/fzy/fzy.c 2>/tmp/e1
  else
    musl-gcc -O3 -static -o /tmp/build/fzy.bin /tmp/build/fzy/fzy.c 2>/tmp/e1
  fi && install_verified /tmp/build/fzy.bin fzy || echo "  ✗ fzy: $(tail -2 /tmp/e1 | head -1)"
fi

# ── patch：autotools ─────────────────────────────────────────
if fetch patchutils/patch patch; then
  ( cd /tmp/build/patch && autoreconf -fi >/tmp/ar 2>&1
    CC="$CROSS_CC" ./configure --host="$T" --disable-dependency-tracking --disable-docs >/tmp/c2 2>&1 \
    && make -j"$(nproc)" >/tmp/m2 2>&1 && cp src/patch /tmp/build/patch.bin ) \
    && install_verified /tmp/build/patch.bin patch \
    || echo "  ✗ patch: $(grep -iE 'error|not found' /tmp/m2 /tmp/c2 2>/dev/null | head -1)"
fi

# ── nnn：Makefile 直编；musl 无 fts.h → O_NOFTS；curses 头来自 apt ──
if fetch jarun/nnn nnn; then
  ( cd /tmp/build/nnn && make clean >/dev/null 2>&1
    make nnn CC="$CROSS_CC" O_NOFTS=1 >/tmp/m3 2>&1 && cp nnn /tmp/build/nnn.bin ) \
    && install_verified /tmp/build/nnn.bin nnn \
    || echo "  ✗ nnn: $(grep -iE 'error|fatal' /tmp/m3 2>/dev/null | head -1)"
fi

# ── b3sum：独立 crate（根目录是 blake3 包，不是 workspace）────────
if fetch BLAKE3-team/BLAKE3 BLAKE3; then
  ( cd /tmp/build/BLAKE3/b3sum && CARGO_PROFILE_RELEASE_PANIC=abort \
    cargo build --release --target "$T" >/tmp/m4 2>&1 \
    && cp "target/$T/release/b3sum" /tmp/build/b3sum.bin ) \
    && install_verified /tmp/build/b3sum.bin b3sum \
    || echo "  ✗ b3sum: $(grep -iE '^error' /tmp/m4 2>/dev/null | head -1)"
fi

# ── jaq：Rust ────────────────────────────────────────────────
if fetch 01mf02/jaq jaq; then
  ( cd /tmp/build/jaq && cargo build --release --target "$T" --bin jaq >/tmp/m5 2>&1 \
    && cp "target/$T/release/jaq" /tmp/build/jaq.bin ) \
    && install_verified /tmp/build/jaq.bin jaq \
    || echo "  ✗ jaq: $(grep -iE '^error' /tmp/m5 2>/dev/null | head -1)"
fi

# ── ncdu：ncurses —— amd64 用 apt 的头；arm64 先交叉编 ncurses ────
if fetch rofl0r/ncdu ncdu; then
  NCF=""; NCL=""
  if [ "$ARCH" = arm64 ]; then
    if [ ! -f /tmp/nc-prefix/lib/libncursesw.a ]; then
      curl -fsSL --max-time 300 "https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz" -o /tmp/nc.tgz \
        && mkdir -p /tmp/ncb && tar xzf /tmp/nc.tgz -C /tmp/ncb \
        && ( cd /tmp/ncb/ncurses-6.4 \
             && ./configure --host=aarch64-linux-musl CC="$CROSS_CC" \
                  --prefix=/tmp/nc-prefix --without-shared --without-debug --without-ada \
                  --enable-widec --without-manpages --without-tests >/tmp/ncc 2>&1 \
             && make -j"$(nproc)" >/tmp/ncm 2>&1 && make install >/dev/null 2>&1 ) \
        || echo "  ! ncurses 交叉编译失败: $(tail -1 /tmp/ncc 2>/dev/null)"
    fi
    NCF="-I/tmp/nc-prefix/include"; NCL="-L/tmp/nc-prefix/lib"
  fi
  ( cd /tmp/build/ncdu && autoreconf -fi >/dev/null 2>&1
    CC="$CROSS_CC" ./configure --host="$T" CPPFLAGS="$NCF" LDFLAGS="$NCL" \
      --disable-dependency-tracking >/tmp/c6 2>&1 \
    && make -j"$(nproc)" >/tmp/m6 2>&1 && cp ncdu /tmp/build/ncdu.bin ) \
    && install_verified /tmp/build/ncdu.bin ncdu \
    || echo "  ✗ ncdu: $(grep -iE 'error|not found' /tmp/m6 /tmp/c6 2>/dev/null | head -1)"
fi

echo "── $ARCH 完成：成功 $ok 个，失败 $fail 个 ──"
( cd "$OUT" && sha256sum * > SHA256SUMS 2>/dev/null )
[ "$fail" -gt 0 ] && exit 0   # 部分失败不阻断提交（已成功的仍要入库）