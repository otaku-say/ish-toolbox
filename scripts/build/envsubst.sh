#!/bin/bash
# envsubst.sh —— 环境变量替换（GNU gettext-runtime 的 envsubst；自编译）
# gettext-runtime 子包单独构建；静态化必须 make LDFLAGS="-no-pie -all-static"。
# 取源：统一 GNU 镜像链。版本策略（用户指定）：**1.0 首选、0.26 备选**——
# 构建失败也回退；Debian 池为获取失败时的最后兜底。
# ⚠ 构建用 -j1：gettext 的 gnulib 生成链在并行 make 下有竞态（2026-10 CI 实锤嫌疑）。
. "$(dirname "$0")/_common.sh"

GT_OK=""
VER=$(latest_gnu gettext 'gettext-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz' || true)
echo "  gettext 上游最新: ${VER:-（listing 不可用，转候选版本）}"

build_gt() {  # 在已解压的 /tmp/build/gettext 上构建
  # ⚠ --disable-libasprintf：libasprintf 是 C++ 部件；交叉环境若装有宿主 g++，
  #   configure 会启用它并用宿主 g++（glibc 头）去编，撞 gnulib 的 off64_t
  #   重复定义 —— envsubst 用不到它，直接关（2026-10 CI sh -x 追踪实锤）。
  ( cd /tmp/build/gettext/gettext-runtime \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" \
       ./configure --host="$T" --disable-dependency-tracking --disable-libasprintf >/tmp/c-gt 2>&1 \
    && make -j1 LDFLAGS="-no-pie -all-static" >/tmp/m-gt 2>&1 \
    && cp src/envsubst /tmp/build/envsubst.bin )
}

# ① 1.0 首选 ② 0.26 备选（构建失败也回退）
for V in 1.0 0.26; do
  rm -rf /tmp/build/gettext /tmp/build/gettext-$V
  fetch_gnu "gettext/gettext-$V.tar.xz" "gettext-$V" gettext || continue
  if build_gt; then GT_OK=1; echo "  gettext 采用: $V"; break; fi
  echo "  ! gettext $V 构建失败，尝试下一版本"
  tail -8 /tmp/m-gt 2>/dev/null | sed 's/^/      | /'
  echo "  -- 失败步骤追踪（sh -x 重放，输出尾 40 行）--"
  ( cd /tmp/build/gettext/gettext-runtime 2>/dev/null && make -j1 LDFLAGS="-no-pie -all-static" SHELL="sh -x" >/tmp/m-gt2 2>&1 )
  tail -40 /tmp/m-gt2 2>/dev/null | sed 's/^/      | /'
done
# ③ Debian 池兜底（GNU 侧获取失败时）
if [ -z "$GT_OK" ]; then
  for N in "gettext_1.0.orig.tar.xz:gettext-1.0" "gettext_0.23.1.orig.tar.xz:gettext-0.23.1"; do
    F=${N%%:*}; D=${N#*:}
    rm -rf /tmp/build/gettext
    fetch_url "https://deb.debian.org/debian/pool/main/g/gettext/$F" "$D" gettext || continue
    if build_gt; then GT_OK=1; break; fi
  done
fi
[ -z "$GT_OK" ] && { echo "  ✗ envsubst: gettext 各版本均未能构建"; exit 0; }

install_verified /tmp/build/envsubst.bin envsubst \
  || echo "  ✗ envsubst: 产物验证失败"
