#!/bin/bash
# build-from-source-ci.sh —— 在 GitHub Actions 里编译双架构静态二进制
#
# 由 .github/workflows/build-source.yml 调用，环境变量 ARCH=arm64|amd64。
#
# 这个脚本固化了在沙箱里踩过的**所有**坑：
#   1. Rust 的 musl target 自 1.70+ 默认产 static-pie（Type=DYN、有 PT_INTERP）
#      → 必须 RUSTFLAGS="-C relocation-model=static" 才是纯静态
#   2. musl target **即使原生架构**也要显式 CARGO_TARGET_*_LINKER，否则 cargo
#      打印 warning 后"静默成功"，实际不产出二进制
#   3. BLAKE3 根目录是 [package] blake3 不是 workspace → b3sum 要 cd 进子目录编
#   4. nnn 需要 ncurses 头；musl 无 glibc 的 fts.h → 用 O_NOFTS=1 走回退实现
#   5. autotools 项目从 tarball 来也需要 autoreconf -fi 才有 configure
#   6. 用 tarball 下载而不是 git clone（更可靠、无交互风险）
set -uo pipefail

ARCH="${ARCH:?需要 ARCH=arm64|amd64}"
OUT="tools/$ARCH"
mkdir -p "$OUT" /tmp/build
cd "$(git rev-parse --show-toplevel)"

case "$ARCH" in
  amd64) HOST=x86_64-linux-musl;  CC=musl-gcc;               T=x86_64-unknown-linux-musl ;;
  arm64) HOST=aarch64-linux-musl; CC=aarch64-linux-musl-gcc; T=aarch64-unknown-linux-musl ;;
  *) echo "✗ 未知架构 $ARCH"; exit 1 ;;
esac
K=$(echo "$T" | tr 'a-z-' 'A-Z_')
export CC_$K="$CC" CARGO_TARGET_${K}_LINKER="$CC"
export RUSTFLAGS="-C relocation-model=static"
export CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_LTO=true
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 CARGO_PROFILE_RELEASE_STRIP=symbols

ok=0; fail=0
# 三判据验证 + 落地
install_verified() {  # <二进制路径> <命令名>
  local b="$1" n="$2"
  readelf -l "$b" 2>/dev/null | grep -q INTERP && { echo "  ✗ $n 非静态(PT_INTERP)"; fail=$((fail+1)); return 1; }
  readelf -d "$b" 2>/dev/null | grep -q NEEDED  && { echo "  ✗ $n 非静态(NEEDED)";   fail=$((fail+1)); return 1; }
  local em; em=$(od -An -tx1 -j18 -N1 "$b" | tr -d ' \n')
  local want; [ "$ARCH" = arm64 ] && want=b7 || want=3e
  [ "$em" = "$want" ] || { echo "  ✗ $n 架构不符($em≠$want)"; fail=$((fail+1)); return 1; }
  strip "$b" 2>/dev/null || true
  cp "$b" "$OUT/$n" && chmod +x "$OUT/$n"
  printf '  ✓ %-8s %6.2f MB\n' "$n" "$(awk -v s="$(wc -c < "$OUT/$n")" 'BEGIN{print s/1048576}')"
  ok=$((ok+1))
}

fetch() {  # <owner/repo> <dir> —— 依次试 main / master
  local d="/tmp/build/$2"
  [ -d "$d" ] && return 0
  for br in main master; do
    if curl -fsSL --max-time 180 "https://github.com/$1/archive/refs/heads/$br.tar.gz" -o /tmp/x.tgz; then
      tar xzf /tmp/x.tgz -C /tmp/build && mv "/tmp/build/$2-$br" "$d" 2>/dev/null && return 0
    fi
  done
  echo "  ! 下载失败 $1"; return 1
}

echo "═══ $ARCH (host=$HOST) ═══"

# ── fzy：单文件 C ──────────────────────────────────────────────
if fetch jhawthorn/fzy fzy; then
  ( cd /tmp/build/fzy && $CC -O3 -static -o /tmp/build/fzy.bin fzy.c 2>/tmp/e1 ) \
    && install_verified /tmp/build/fzy.bin fzy || echo "  ✗ fzy: $(tail -1 /tmp/e1 2>/dev/null)"
fi

# ── patch：autotools ──────────────────────────────────────────
if fetch patchutils/patch patch; then
  ( cd /tmp/build/patch && autoreconf -fi >/dev/null 2>&1
    ./configure --host=$HOST CC=$CC --disable-dependency-tracking --disable-docs >/tmp/c2 2>&1 \
    && make -j"$(nproc)" >/tmp/m2 2>&1 && cp src/patch /tmp/build/patch.bin ) \
    && install_verified /tmp/build/patch.bin patch \
    || echo "  ✗ patch: $(tail -1 /tmp/m2 2>/dev/null || tail -1 /tmp/c2 2>/dev/null)"
fi

# ── nnn：Makefile 直编，musl 无 fts.h 用 O_NOFTS ──────────────
if fetch jarun/nnn nnn; then
  ( cd /tmp/build/nnn && make clean >/dev/null 2>&1
    make nnn CC="$CC" O_NOFTS=1 >/tmp/m3 2>&1 && cp nnn /tmp/build/nnn.bin ) \
    && install_verified /tmp/build/nnn.bin nnn \
    || echo "  ✗ nnn: $(grep -iE 'error' /tmp/m3 2>/dev/null | head -1)"
fi

# ── b3sum：独立 crate（根目录不是 workspace）─────────────────
if fetch BLAKE3-team/BLAKE3 BLAKE3; then
  ( cd /tmp/build/BLAKE3/b3sum && CARGO_PROFILE_RELEASE_PANIC=abort \
    cargo build --release --target "$T" >/tmp/m4 2>&1 \
    && cp "target/$T/release/b3sum" /tmp/build/b3sum.bin ) \
    && install_verified /tmp/build/b3sum.bin b3sum \
    || echo "  ✗ b3sum: $(grep -iE '^error' /tmp/m4 2>/dev/null | head -1)"
fi

# ── jaq：Rust ─────────────────────────────────────────────────
if fetch 01mf02/jaq jaq; then
  ( cd /tmp/build/jaq && cargo build --release --target "$T" --bin jaq >/tmp/m5 2>&1 \
    && cp "target/$T/release/jaq" /tmp/build/jaq.bin ) \
    && install_verified /tmp/build/jaq.bin jaq \
    || echo "  ✗ jaq: $(grep -iE '^error' /tmp/m5 2>/dev/null | head -1)"
fi

# ── ncdu：依赖 ncurses（arm64 需先交叉编译 ncurses）───────────
if fetch rofl0r/ncdu ncdu; then
  if [ "$ARCH" = arm64 ]; then
    if [ ! -d /tmp/ncurses-prefix ]; then
      curl -fsSL --max-time 300 "https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz" -o /tmp/nc.tgz \
        && mkdir -p /tmp/ncbuild && tar xzf /tmp/nc.tgz -C /tmp/ncbuild \
        && ( cd /tmp/ncbuild/ncurses-6.4 \
             && ./configure --host=aarch64-linux-musl CC=aarch64-linux-musl-gcc \
                  --prefix=/tmp/ncurses-prefix --without-shared --without-debug \
                  --without-ada --enable-widec --without-manpages >/tmp/ncconf 2>&1 \
             && make -j"$(nproc)" >/tmp/ncmake 2>&1 && make install >/dev/null 2>&1 )
    fi
    NCFLAGS="-I/tmp/ncurses-prefix/include"; NCLIBS="-L/tmp/ncurses-prefix/lib"
  else
    NCFLAGS=""; NCLIBS=""     # amd64 用 apt 装的 libncurses-dev
  fi
  ( cd /tmp/build/ncdu && autoreconf -fi >/dev/null 2>&1
    ./configure --host=$HOST CC=$CC CPPFLAGS="$NCFLAGS" LDFLAGS="$NCLIBS" \
      --disable-dependency-tracking >/tmp/c6 2>&1 \
    && make -j"$(nproc)" >/tmp/m6 2>&1 && cp ncdu /tmp/build/ncdu.bin ) \
    && install_verified /tmp/build/ncdu.bin ncdu \
    || echo "  ✗ ncdu: $(tail -1 /tmp/m6 2>/dev/null || tail -1 /tmp/c6 2>/dev/null)"
fi

echo "── $ARCH 完成：成功 $ok 个，失败 $fail 个 ──"
[ -f "$OUT/SHA256SUMS" ] && ( cd "$OUT" && sha256sum * > SHA256SUMS ) || ( cd "$OUT" && sha256sum * > SHA256SUMS )
exit 0