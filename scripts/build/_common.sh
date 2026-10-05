#!/bin/bash
# _common.sh —— 构建脚本公共层（被 scripts/build/<tool>.sh source）
#
# 提供：架构环境、体积优化标志、三判据验证、下载工具函数。
# 环境变量 ARCH 必须由调用方设置（arm64 | amd64）。

ARCH="${ARCH:?需要 ARCH=arm64|amd64}"
OUT="tools/$ARCH"
mkdir -p "$OUT" /tmp/build

case "$ARCH" in
  amd64) T=x86_64-unknown-linux-musl;  EM=3e; CROSS_CC=musl-gcc ;;
  arm64) T=aarch64-unknown-linux-musl; EM=b7; CROSS_CC=/tmp/zigcc ;;
  *) echo "✗ 未知架构 $ARCH"; exit 1 ;;
esac
K=$(echo "$T" | tr 'a-z-' 'A-Z_')
export CC_$K="$CROSS_CC" CARGO_TARGET_${K}_LINKER=rust-lld
[ "$ARCH" = amd64 ] && export CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc

# ── 体积最小化的统一标志 ─────────────────────────────────────────
# C 侧：-Os 尺寸优先 / 分节 + 链接期 gc 剔除未引用段 /
#       去掉异常表与编译器标识（几项加起来常能再省 5-15%）
#       注意：-static 必须同时出现在 CFLAGS（部分 Makefile 链接时只用它）
CSIZE="-Os -ffunction-sections -fdata-sections -fno-asynchronous-unwind-tables -fno-unwind-tables -fno-ident -static"
CLINK="-static -Wl,--gc-sections -Wl,--strip-all"
# Rust 侧：opt-level=z + fat LTO + 单 codegen unit + strip + abort panic
#         relocation-model=static 是**纯静态非 PIE** 的关键（否则 Type=DYN 有 INTERP）
export RUSTFLAGS="${RUSTFLAGS:-} -C relocation-model=static -C opt-level=z -C lto=fat -C codegen-units=1 -C strip=symbols -C panic=abort"
export CARGO_PROFILE_RELEASE_OPT_LEVEL=z CARGO_PROFILE_RELEASE_LTO=true
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 CARGO_PROFILE_RELEASE_STRIP=symbols
export CARGO_PROFILE_RELEASE_PANIC=abort

# 为 arm64 准备 Zig 的 C 编译器 wrapper（幂等）
if [ "$ARCH" = arm64 ] && [ ! -x /tmp/zigcc ]; then
  printf '#!/bin/sh\nexec zig cc -target aarch64-linux-musl "$@"\n' > /tmp/zigcc
  chmod +x /tmp/zigcc
fi

# ── 三判据验证后落地（含可选的 UPX 压缩）────────────────────────
# UPX 默认开启（UPX=0 可关闭）。实测 UPX 的自解压 stub **不引入 PT_INTERP**，
# 压缩后三判据（无 INTERP / 无 NEEDED / 架构正确）依然成立，
# 且压缩后真机可运行。先 strip 再 UPX，并用运行测试兜底：
#   UPX 后跑不起来就自动回退到未压缩版本（安全第一）。
: "${UPX:=1}"
run_ok() { "$1" --version >/dev/null 2>&1 || "$1" --help >/dev/null 2>&1; }

install_verified() {  # <路径> <命令名>
  local b="$1" n="$2"
  [ -f "$b" ] || { echo "  ✗ $n 产物不存在"; return 1; }
  readelf -l "$b" 2>/dev/null | grep -q INTERP && { echo "  ✗ $n 非静态(PT_INTERP)"; return 1; }
  readelf -d "$b" 2>/dev/null | grep -q NEEDED  && { echo "  ✗ $n 非静态(NEEDED)";   return 1; }
  local em; em=$(od -An -tx1 -j18 -N1 "$b" | tr -d ' \n')
  [ "$em" = "$EM" ] || { echo "  ✗ $n 架构不符($em≠$EM)"; return 1; }
  strip --strip-all "$b" 2>/dev/null || true
  local pre; pre=$(wc -c < "$b")
  local note=""
  if [ "$UPX" = 1 ] && command -v upx >/dev/null 2>&1; then
    cp "$b" "$b.pre-upx"
    if upx --best -q "$b" 2>/dev/null && run_ok "$b"; then
      note=" +UPX $(awk -v a="$pre" -v c="$(wc -c < "$b")" 'BEGIN{printf "%d%%", c*100/a}')"
    else
      mv "$b.pre-upx" "$b"; note=" (UPX 跳过)"
    fi
    rm -f "$b.pre-upx"
  fi
  cp "$b" "$OUT/$n" && chmod +x "$OUT/$n"
  printf '  ✓ %-8s %6.2f MB%s\n' "$n" "$(awk -v s="$(wc -c < "$OUT/$n")" 'BEGIN{print s/1048576}')" "$note"
}

# GitHub 源码 tarball（依次试 main / master）
fetch() {  # <owner/repo> <dir>
  local d="/tmp/build/$2"; [ -d "$d" ] && return 0
  for br in main master; do
    curl -fsSL --max-time 180 "https://github.com/$1/archive/refs/heads/$br.tar.gz" -o /tmp/x.tgz 2>/dev/null \
      && tar xzf /tmp/x.tgz -C /tmp/build 2>/dev/null \
      && mv "/tmp/build/$2-$br" "$d" 2>/dev/null && return 0
  done
  echo "  ! 下载失败 $1"; return 1
}

# 任意 URL 的 tarball（官方 release 包，自带 configure）
fetch_url() {  # <url> <解压目录名> <目标名>
  local d="/tmp/build/$3"; [ -d "$d" ] && return 0
  curl -fsSL --max-time 300 "$1" -o /tmp/x.tgz 2>/dev/null \
    && tar xzf /tmp/x.tgz -C /tmp/build 2>/dev/null \
    && mv "/tmp/build/$2" "$d" 2>/dev/null && return 0
  echo "  ! 下载失败 $1"; return 1
}

# 查上游最新版本对应的 tarball URL（有些项目不发 GitHub Release，
# 只能从官方目录列表里挑版本号最大的）
latest_from_listing() {  # <目录URL> <文件名正则>
  curl -fsSL --max-time 60 "$1" 2>/dev/null \
    | grep -oE "$2" | sort -V | tail -1
}
