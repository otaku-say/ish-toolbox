#!/bin/bash
# =============================================================================
# uv.sh —— 官方 uv（musl 静态）→ 自解压壳单文件
#   产物：tools/uv/<arch>/uv（[静态壳][xz(BCJ) 载荷][72B 尾部]；首次运行解压到 /tmp）
#   用法：ARCH=arm64|amd64 [UV_VERSION=0.12.24|latest] bash scripts/build/uv.sh
#   依赖：dyn-common.sh（工具链 / xz / xz-embedded / 壳）
#   UV_VERSION=latest 时先做稳定性过滤（排除 prerelease/draft），失败自动回退固定版本。
# =============================================================================
set -euo pipefail
trap 'rc=$?; [ "$rc" -eq 0 ] || echo "✗ uv 构建失败（rc=$rc）"' EXIT

ARCH="${ARCH:?用法: ARCH=arm64|amd64 bash scripts/build/uv.sh}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/dyn-common.sh"

case "$ARCH" in
  arm64) TRIPLE=aarch64-unknown-linux-musl; EM=b7 ;;
  amd64) TRIPLE=x86_64-unknown-linux-musl;  EM=3e ;;
  *) echo "✗ 未知架构 $ARCH"; exit 1 ;;
esac

dyn_setup

UV_DEFAULT=0.12.24
UV_VERSION="${UV_VERSION:-$UV_DEFAULT}"
if [ "$UV_VERSION" = latest ]; then
  V="$(curl -fsSL --max-time 30 https://api.github.com/repos/astral-sh/uv/releases 2>/dev/null \
       | python3 -c 'import json,sys
rs=[r for r in json.load(sys.stdin) if not r.get("prerelease") and not r.get("draft")]
print(rs[0]["tag_name"] if rs else "")' 2>/dev/null || true)"
  [ -n "$V" ] || { echo "⚠ latest 解析失败，回退 $UV_DEFAULT"; V="$UV_DEFAULT"; }
  UV_VERSION="${V#v}"
fi
echo "=== uv $UV_VERSION ($ARCH) ==="

W="${WORK:-/tmp/uv-build-$ARCH}"
mkdir -p "$W"
A="uv-$TRIPLE.tar.gz"
URL="https://github.com/astral-sh/uv/releases/download/$UV_VERSION/$A"
[ -f "$W/$A" ] || curl -fL --retry 3 --max-time 600 -o "$W/$A" "$URL"
[ -f "$W/$A.sha256" ] || curl -fL --retry 3 --max-time 60 -o "$W/$A.sha256" "$URL.sha256"
EXP="$(awk '{print $1}' "$W/$A.sha256")"
ACT="$(sha256sum "$W/$A" | awk '{print $1}')"
if [ -z "$EXP" ] || [ "$EXP" != "$ACT" ]; then
  echo "✗ 官方 sha256 校验失败：期望 $EXP 实际 $ACT"; exit 1
fi
echo "  sha256 校验通过：$ACT"

rm -rf "$W/x"; mkdir -p "$W/x"
tar xzf "$W/$A" -C "$W/x"
BIN="$W/x/$TRIPLE/uv"
[ -f "$BIN" ] || BIN="$(find "$W/x" -type f -name uv -print -quit)"
[ -f "$BIN" ] || { echo "✗ 包内找不到 uv"; exit 1; }

# 三判据（静态 / 无 NEEDED / 架构正确）——与 scripts/doctor.sh 同一判定
L="$(readelf -l "$BIN" 2>/dev/null || true)"
case "$L" in *INTERP*) echo "✗ uv 非静态（有 PT_INTERP）"; exit 1 ;; esac
D="$(readelf -d "$BIN" 2>/dev/null || true)"
case "$D" in *NEEDED*) echo "✗ uv 非静态（有 NEEDED）"; exit 1 ;; esac
em=$(od -An -tx1 -j18 -N1 "$BIN" 2>/dev/null | tr -d ' \n')
[ "$em" = "$EM" ] || { echo "✗ 架构不符（e_machine=$em，期望 $EM）"; exit 1; }
echo "  上游 uv 通过三判据（静态 + e_machine=$em）"

echo "=== 自解压壳打包（xz BCJ）==="
STUB="$W/py3dyn-stub-$ARCH"
dyn_build_stub "$STUB"
OUTDIR="$ROOT/tools/uv/$ARCH"
mkdir -p "$OUTDIR"
dyn_package "$STUB" "$BIN" "$OUTDIR/uv" uv

rm -rf /tmp/.ish-py3dyn-*
Q="$(dyn_qemu)"
VER_OUT="$($Q "$OUTDIR/uv" --version 2>&1)" || { echo "✗ 壳运行失败：$VER_OUT"; exit 1; }
case "$VER_OUT" in
  *"uv $UV_VERSION"*) echo "  壳终验: $VER_OUT" ;;
  *) echo "✗ 版本不符：$VER_OUT"; exit 1 ;;
esac

cp "$OUTDIR/uv" "/tmp/uv-$ARCH-single"
echo "=== uv 完成（$ARCH）==="
ls -la "$OUTDIR/uv" | awk '{print $5, $NF}'
sha256sum "$OUTDIR/uv"
