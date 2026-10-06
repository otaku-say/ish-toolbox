#!/bin/bash
# hxselect.sh —— 按 CSS 选择器从 HTML/XML 提取元素（W3C html-xml-utils）
# 只交付 hxselect 单个二进制（源码包含 ~40 个工具，其余不取）。
# ⚠ gnulib 在交叉编译时跑不了 "malloc(0)/realloc(0) 行为测试" → 误启用 rpl_* 替换
#   （报 undefined rpl_malloc）→ 用 ac_/gl_ 两套拼写的 cache 变量强制"系统函数正常"。
. "$(dirname "$0")/_common.sh"

VER=8.8
if fetch_url "https://www.w3.org/Tools/HTML-XML-utils/html-xml-utils-$VER.tar.gz" "html-xml-utils-$VER" hxu; then
  ( cd /tmp/build/hxu \
    && ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes \
       gl_cv_func_malloc_0_nonnull=yes gl_cv_func_realloc_0_nonnull=yes \
       CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" ./configure --host="$T" >/tmp/c-hxu 2>&1 \
    && make -j"$(nproc)" >/tmp/m-hxu 2>&1 \
    && cp hxselect /tmp/build/hxselect.bin ) \
    && install_verified /tmp/build/hxselect.bin hxselect \
    || echo "  ✗ hxselect: $(grep -iE 'error|not found' /tmp/m-hxu /tmp/c-hxu 2>/dev/null | head -1 | cut -c1-110)"
fi
