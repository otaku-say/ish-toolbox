#!/bin/bash
# micropython.sh —— MicroPython unix port（官方只发源码，全平台都要自己编）
#
# 上游最新：GitHub release 的源码 tarball（自带 lib/ 子模块快照）
# 静态化：MICROPY_STANDALONE=1（自编 libffi/mbedtls/berkeley-db 等全部依赖）
#         + -static 全静态链接，产物三判据成立
# 交叉：arm64 用 Debian 的 aarch64-linux-gnu-gcc（apt 装，CROSS_COMPILE 前缀机制）
#       amd64 用 runner 本机 gcc
. "$(dirname "$0")/_common.sh"

# 1) 拿最新源码 tarball URL（157MB，压缩包内含子模块快照，不折腾 git submodule）
API=/tmp/mpy.json
curl -fsSL --max-time 60 ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/micropython/micropython/releases/latest" -o "$API" 2>/dev/null
URL=$(jq -r '[.assets[]? | select(.name|test("^micropython-[0-9.]+\\.tar\\.xz$")) | .browser_download_url][0] // empty' "$API" 2>/dev/null)
[ -z "$URL" ] && { echo "  ✗ micropython 拿不到源码包"; exit 0; }

# 2) 下载 + 解压（带缓存，重复构建时秒过）
if [ ! -d /tmp/build/micropython/ports/unix ]; then
  echo "  下载源码 $(basename "$URL")…"
  curl -fsSL --max-time 900 -o /tmp/mpy.tar.xz "$URL" 2>/dev/null \
    || { echo "  ✗ micropython 下载失败"; exit 0; }
  tar xJf /tmp/mpy.tar.xz -C /tmp/build 2>/dev/null \
    || { echo "  ✗ micropython 解压失败"; exit 0; }
  mv /tmp/build/micropython-[0-9]* /tmp/build/micropython 2>/dev/null
fi

# 3) 编译（官方 standalone 流程：tarball 自带子模块 → 先 deplibs 编 libffi → 再主构建）
#    之前漏了 deplibs 一步，报 "ls: cannot access 'build-standard/lib/libffi/include'"。
#    编译在子 shell 里做（install_verified 的 OUT 是相对路径，必须在外层调）
XC=""; [ "$ARCH" = arm64 ] && XC="CROSS_COMPILE=aarch64-linux-gnu-"
rm -f /tmp/build/mpy.bin
( cd /tmp/build/micropython/ports/unix \
  && { make -j"$(nproc)" MICROPY_STANDALONE=1 $XC deplibs \
       && make -j"$(nproc)" MICROPY_STANDALONE=1 $XC LDFLAGS_EXTRA="-static"; } >/tmp/m-mpy 2>&1 \
  && find . -type f -name micropython -perm -u+x -size +300k | head -1 | xargs -r -I{} cp {} /tmp/build/mpy.bin )

# 4) 验证（子 shell 已把产物拷到 /tmp/build/mpy.bin）
if [ -f /tmp/build/mpy.bin ]; then
  install_verified /tmp/build/mpy.bin micropython
else
  echo "  ✗ micropython: $(grep -iE 'error|cannot|No rule' /tmp/m-mpy 2>/dev/null | head -1 | cut -c1-110)"
fi
