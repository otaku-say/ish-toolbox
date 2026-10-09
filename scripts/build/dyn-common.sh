#!/bin/bash
# =============================================================================
# dyn-common.sh —— 「自解压壳单文件」公共构件（python3 / uv 共用）
#
# 单文件布局: [静态壳 ELF][xz(BCJ) 压缩载荷][72B 尾部记录]
#   尾部: magic(16) + id(16) + name(16) + u64 pay_off + u64 pay_size + u64 out_size
#   首次运行解压到 /tmp/.ish-py3dyn-<id>/，之后每次运行只做 stat + exec（零开销）。
#
# 被 scripts/build/python3.sh、scripts/build/uv.sh source 后使用：
#   dyn_setup            准备：Bootlin musl 工具链×2、xz 5.6.4、xz-embedded、musl loader
#   dyn_build_stub <out> 编译静态壳（xz-embedded 解码器）
#   dyn_package <壳> <载荷> <输出> <名字>   组装单文件（xz BCJ 压缩 + 尾部记录）
#
# 也可独立运行做环境准备：bash scripts/build/dyn-common.sh --setup
# 环境：ARCH=arm64|amd64（除 --setup 外必需）；DYN_ROOT 默认 /tmp/dyn-shared
# =============================================================================
set -euo pipefail

DYN_ROOT="${DYN_ROOT:-/tmp/dyn-shared}"
DYN_XZVER=5.6.4
DYN_XZE_TAG=v2024-12-30
DYN_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_dyn_arch() {
  case "${ARCH:?需要 ARCH=arm64|amd64}" in
    arm64|amd64) printf '%s\n' "$ARCH" ;;
    *) printf '✗ 未知架构 %s\n' "$ARCH" >&2; return 1 ;;
  esac
}
dyn_cc() {
  case "$(_dyn_arch)" in
    arm64) printf '%s\n' /opt/musl-a64/bin/aarch64-linux-gcc ;;
    amd64) printf '%s\n' /opt/musl-x64/bin/x86_64-linux-gcc ;;
  esac
}
dyn_strip_path() {
  case "$(_dyn_arch)" in
    arm64) printf '%s\n' /opt/musl-a64/bin/aarch64-linux-strip ;;
    amd64) printf '%s\n' /opt/musl-x64/bin/x86_64-linux-strip ;;
  esac
}
dyn_bcj() { case "$(_dyn_arch)" in arm64) echo --arm64 ;; amd64) echo --x86 ;; esac; }
dyn_qemu() { case "$(_dyn_arch)" in arm64) echo qemu-aarch64-static ;; amd64) echo ;; esac; }

_dyn_sudo() {
  if [ "$(id -u)" != 0 ] && command -v sudo >/dev/null 2>&1; then echo sudo; fi
}

# ── Bootlin musl 工具链（GCC 12.3.0）→ /opt/musl-a64 或 /opt/musl-x64 ──
#     安装后统一 <arch>-linux-* 前缀（两个来源命名不同）
dyn_install_toolchain() {
  local arch t url_dir name linkp bld ml tb SUDO
  arch="$(_dyn_arch)"
  case "$arch" in
    arm64) t=/opt/musl-a64; url_dir=aarch64; name=aarch64--musl--stable-2024.02-1
           linkp=aarch64-linux; bld=aarch64-buildroot-linux-musl; ml=aarch64-linux-musl ;;
    amd64) t=/opt/musl-x64; url_dir=x86-64;   name=x86-64--musl--stable-2024.02-1
           linkp=x86_64-linux;  bld=x86_64-buildroot-linux-musl;  ml=x86_64-linux-musl ;;
  esac
  SUDO="$(_dyn_sudo)"
  if [ ! -x "$t/bin/$linkp-gcc" ]; then
    echo "→ 安装 Bootlin musl 工具链（$arch）"
    tb="/tmp/dyn-toolchain-$arch.tar.bz2"
    [ -f "$tb" ] || curl -fSL --retry 3 --max-time 600 -o "$tb" \
      "https://toolchains.bootlin.com/downloads/releases/toolchains/$url_dir/tarballs/$name.tar.bz2"
    rm -rf "/tmp/$name"
    tar xjf "$tb" -C /tmp
    $SUDO mkdir -p "$t"
    $SUDO cp -a "/tmp/$name/." "$t/"
    rm -rf "/tmp/$name"
  fi
  ( cd "$t/bin" 2>/dev/null || exit 0
    for c in gcc g++ ld ar strip nm; do
      if [ ! -e "$linkp-$c" ]; then
        for cand in "$bld-$c" "$ml-$c"; do
          [ -e "$cand" ] && { $SUDO ln -sf "$cand" "$linkp-$c"; break; }
        done
      fi
    done )
  [ -x "$t/bin/$linkp-gcc" ] || { printf '✗ 工具链安装失败：%s/bin/%s-gcc\n' "$t" "$linkp" >&2; return 1; }
  "$t/bin/$linkp-gcc" --version | sed -n '1p'
}

# ── musl loader → /lib（运行动态 musl 产物所需；iSH/Alpine 自带，CI/glibc 环境补齐）──
dyn_install_loader() {
  local arch ld t src SUDO
  arch="$(_dyn_arch)"
  case "$arch" in
    arm64) t=/opt/musl-a64; ld=ld-musl-aarch64.so.1 ;;
    amd64) t=/opt/musl-x64; ld=ld-musl-x86_64.so.1 ;;
  esac
  [ -e "/lib/$ld" ] && return 0
  src="$(find "$t" -name "$ld" -print -quit 2>/dev/null || true)"
  [ -n "$src" ] || { printf '⚠ 找不到 %s（%s）；运行校验可能失败\n' "$ld" "$t" >&2; return 0; }
  SUDO="$(_dyn_sudo)"
  if $SUDO mkdir -p /lib 2>/dev/null && $SUDO cp -f "$src" "/lib/$ld" 2>/dev/null && $SUDO chmod 755 "/lib/$ld" 2>/dev/null; then
    echo "→ loader 就位：/lib/$ld"
  else
    printf '⚠ 无法安装 loader 到 /lib（%s）\n' "$ld" >&2
  fi
}

# ── xz 5.6.4（含 --arm64/--x86 BCJ 过滤器；系统 xz 版本普遍不够）──
dyn_install_xz() {
  DYN_XZ="$DYN_ROOT/xz-$DYN_XZVER/src/xz/xz"
  [ -x "$DYN_XZ" ] && return 0
  echo "→ 构建 xz $DYN_XZVER（BCJ 过滤器）"
  mkdir -p "$DYN_ROOT"; cd "$DYN_ROOT"
  local tb="xz-$DYN_XZVER.tar.gz"
  [ -f "$tb" ] || curl -fL --retry 3 --max-time 600 -o "$tb" \
    "https://github.com/tukaani-project/xz/releases/download/v$DYN_XZVER/$tb"
  rm -rf "xz-$DYN_XZVER"
  tar xzf "$tb"
  ( cd "xz-$DYN_XZVER" && ./configure --quiet >/dev/null 2>&1 && make -j"$(nproc 2>/dev/null || echo 2)" >/dev/null 2>&1 )
  [ -x "$DYN_XZ" ] || { echo "✗ xz 构建失败" >&2; return 1; }
  "$DYN_XZ" --version | sed -n '1p'
}

# ── xz-embedded 源码（壳内解码器）──
dyn_install_xze() {
  DYN_XZE="$DYN_ROOT/xz-embedded"
  [ -f "$DYN_XZE/userspace/Makefile" ] && return 0
  echo "→ 获取 xz-embedded $DYN_XZE_TAG"
  mkdir -p "$DYN_ROOT"; cd "$DYN_ROOT"
  local tb="xz-embedded-$DYN_XZE_TAG.tar.gz" d
  [ -f "$tb" ] || curl -fL --retry 3 --max-time 600 -o "$tb" \
    "https://github.com/tukaani-project/xz-embedded/archive/refs/tags/$DYN_XZE_TAG.tar.gz"
  rm -rf "$DYN_XZE"
  d="$(tar tzf "$tb" | sed -n '1p' | cut -d/ -f1)"
  [ -n "$d" ] || { echo "✗ xz-embedded 包异常" >&2; return 1; }
  tar xzf "$tb"
  mv "$d" "$DYN_XZE"
}

# ── 静态壳编译（xz-embedded 六对象 + py3dyn-stub.c）──
dyn_build_stub() {
  local out="$1" cc
  cc="$(dyn_cc)"
  echo "→ 编译自解压壳（$ARCH）"
  ( cd "$DYN_XZE/userspace"
    rm -f xz_crc32.o xz_crc64.o xz_sha256.o xz_dec_stream.o xz_dec_lzma2.o xz_dec_bcj.o
    make CC="$cc" xz_crc32.o xz_crc64.o xz_sha256.o xz_dec_stream.o xz_dec_lzma2.o xz_dec_bcj.o >/dev/null
    "$cc" -static -Os -s -std=gnu11 \
      -I../linux/include/linux -I. \
      -DXZ_DEC_X86 -DXZ_DEC_ARM -DXZ_DEC_ARMTHUMB -DXZ_DEC_ARM64 -DXZ_DEC_RISCV \
      -DXZ_DEC_POWERPC -DXZ_DEC_IA64 -DXZ_DEC_SPARC \
      -DXZ_USE_CRC64 -DXZ_USE_SHA256 -DXZ_DEC_ANY_CHECK -DXZ_DEC_CONCATENATED \
      -o "$out" "$DYN_HERE/py3dyn-stub.c" \
      xz_crc32.o xz_crc64.o xz_sha256.o xz_dec_stream.o xz_dec_lzma2.o xz_dec_bcj.o )
  echo "  壳大小：$(wc -c < "$out") B"
}

# ── 单文件组装：壳 + xz(BCJ) 载荷 + 72B 尾部 ──
dyn_package() {
  local stub="$1" payload="$2" out="$3" name="$4"
  local tmp
  tmp="$(mktemp -d)"
  "$DYN_XZ" --check=crc32 "$(dyn_bcj)" --lzma2=preset=9,dict=16MiB -c "$payload" > "$tmp/payload.xz"
  python3 - "$stub" "$tmp/payload.xz" "$payload" "$out" "$name" <<'PYEOF'
import sys, os, struct, hashlib
stub, xz_path, payload_path, out, name = sys.argv[1:6]
nb = name.encode()
assert 0 < len(nb) <= 16, "name must be 1..16 bytes"
sb = open(stub, 'rb').read()
pz = open(xz_path, 'rb').read()
payload_size = os.path.getsize(payload_path)
id16 = hashlib.sha256(pz).hexdigest()[:16].encode()
tr = b'ISH-PY3DYN-PAYL1' + id16 + nb.ljust(16, b'\x00') + struct.pack('<QQQ', len(sb), len(pz), payload_size)
assert len(tr) == 72, len(tr)
with open(out, 'wb') as f:
    f.write(sb)
    f.write(pz)
    f.write(tr)
os.chmod(out, 0o755)
print('  OK -> %s  total=%d  stub=%d  xz=%d  raw=%d  id=%s  name=%s'
      % (out, os.path.getsize(out), len(sb), len(pz), payload_size, id16.decode(), name))
PYEOF
  rm -rf "$tmp"
  sha256sum "$out"
}

dyn_setup() {
  dyn_install_toolchain
  dyn_install_xz
  dyn_install_xze
  dyn_install_loader
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    --setup)
      if [ -n "${ARCH:-}" ]; then
        dyn_setup
      else
        for a in arm64 amd64; do
          echo "═══ $a ═══"
          ARCH="$a" dyn_setup
        done
      fi
      echo "✓ 动态构建环境就绪（DYN_ROOT=$DYN_ROOT）"
      ;;
    *)
      echo "用法: ARCH=arm64|amd64 bash scripts/build/dyn-common.sh --setup"
      exit 2
      ;;
  esac
fi
