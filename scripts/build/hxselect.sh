#!/bin/bash
# hxselect.sh —— 按 CSS 选择器从 HTML/XML 提取元素（W3C html-xml-utils）
# 只交付 hxselect 单个二进制（源码包里有 ~40 个工具，其余不取）。
# 本工具替代原 cascadia（同步清单已同步移除 cascadia）。
. "$(dirname "$0")/_common.sh"

VER=8.8
if fetch_url "https://www.w3.org/Tools/HTML-XML-utils/html-xml-utils-$VER.tar.gz" "html-xml-utils-$VER" hxu; then
  ( cd /tmp/build/hxu \
    && CC="$CROSS_CC" CFLAGS="$CSIZE" LDFLAGS="$CLINK" ./configure --host="$T" >/tmp/c-hxu 2>&1 \
    && make -j"$(nproc)" >/tmp/m-hxu 2>&1 \
    && cp hxselect /tmp/build/hxselect.bin ) \
    && UPX=0 install_verified /tmp/build/hxselect.bin hxselect \
    || echo "  ✗ hxselect: $(grep -iE 'error|not found' /tmp/m-hxu /tmp/c-hxu 2>/dev/null | head -1 | cut -c1-110)"
fi
