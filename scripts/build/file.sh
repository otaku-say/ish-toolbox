#!/bin/bash
# file.sh —— GNU file(1)（自编译：交叉静态 + 配套 magic.mgc 数据文件）
#
# 两个产物：
#   file       主程序（全静态）
#   magic.mgc  magic 数据库（架构无关数据文件；wrapper 自动经 MAGIC 指向同目录）
# 构建要点（源码实证）：
#   · magic.mgc 的格式与 file 版本绑定；上游交叉构建链要求“同版本原生 file”
#     来执行 `file -C -m magic`（FILE_COMPILE 传全路径时自动跳过版本校验）
#     → 先构建宿主原生 file，再交叉构建目标 file，最后用它编 mgc
#   · file 是 libtool 项目（LT_INIT）→ 最终链接用 -all-static 才真全静态
#   · 关掉 zlib/bzlib/lzlib/lrziplib：交叉环境没有目标静态库，防误链宿主库
. "$(dirname "$0")/_common.sh"

F=$(latest_from_listing "https://astron.com/pub/file/" 'file-5\.[0-9]+\.tar\.gz' | sort -uV | tail -1)
[ -z "$F" ] && { echo "  ! file 版本查询失败"; exit 0; }
V=${F%.tar.gz}                    # 例：file-5.48
echo "  file 上游: $F"

D="/tmp/build/$V"
if [ ! -d "$D" ]; then
  curl -fsSL --max-time 120 "https://astron.com/pub/file/$F" -o /tmp/build/file.tgz 2>/dev/null \
    && tar xzf /tmp/build/file.tgz -C /tmp/build 2>/dev/null \
    || { echo "  ✗ file 下载/解包失败"; exit 0; }
fi

# 1) 宿主原生 file（供 magic.mgc 编译；与目标同版本，格式必兼容）
# 踩坑点：magic.h 是 BUILT_SOURCES（由 magic.h.in 生成、tarball 无此文件），
# 定向构建（make -C src file）不会自动生成它 → 必须先显式 make magic.h
HOSTD="/tmp/build/$V-host"
if [ ! -x "$HOSTD/src/file" ]; then
  rm -rf "$HOSTD"; cp -R "$D" "$HOSTD"
  ( cd "$HOSTD" \
    && ./configure --disable-zlib --disable-bzlib --disable-lzlib --disable-lrziplib >/tmp/f-host.log 2>&1 \
    && make -j"$(nproc)" -C src magic.h >>/tmp/f-host.log 2>&1 \
    && make -j"$(nproc)" -C src file >>/tmp/f-host.log 2>&1 ) \
    || { echo "  ✗ 宿主 file 构建失败: $(tail -2 /tmp/f-host.log | tr '\n' ' ' | cut -c1-110)"; exit 0; }
fi
HOSTFILE="$HOSTD/src/file"

# 2) 交叉构建目标 file + magic.mgc
( cd "$D" \
  && CC="$CROSS_CC" CFLAGS="$CSIZE" ./configure --host="$T" \
       --disable-zlib --disable-bzlib --disable-lzlib --disable-lrziplib \
       --disable-shared --enable-static --disable-dependency-tracking >/tmp/f-cross.log 2>&1 \
  && make -j"$(nproc)" -C src magic.h >>/tmp/f-cross.log 2>&1 \
  && make -j"$(nproc)" -C src file LDFLAGS="-no-pie -all-static" >>/tmp/f-cross.log 2>&1 \
  && make -j"$(nproc)" -C magic magic.mgc FILE_COMPILE="$HOSTFILE" >>/tmp/f-cross.log 2>&1 ) \
  || { echo "  ✗ file 构建失败: $(grep -iE 'error' /tmp/f-cross.log 2>/dev/null | head -1 | cut -c1-110)"; exit 0; }

B="$D/src/file"
[ -f "$B" ] || { echo "  ✗ file 未产出"; exit 0; }
file "$B" | grep -q 'statically linked' || { echo "  ✗ file 非全静态: $(file -b "$B" | cut -c1-80)"; exit 0; }
install_verified "$B" file

MGC="$D/magic/magic.mgc"
[ -s "$MGC" ] || { echo "  ✗ magic.mgc 未产出"; exit 0; }
cp "$MGC" "$OUT/magic.mgc"
printf '  ✓ %-8s %6.2f MB (magic.mgc %5.2f MB)\n' file \
  "$(awk -v s="$(wc -c < "$OUT/file")" 'BEGIN{print s/1048576}')" \
  "$(awk -v s="$(wc -c < "$OUT/magic.mgc")" 'BEGIN{print s/1048576}')"
