#!/bin/bash
# sqlite3.sh —— SQLite 命令行（官方预编译只有 x64，aarch64 用 amalgamation 源码自编）
#
# amalgamation = sqlite3.c + shell.c 两个文件，一条命令编完；
# 裁剪：不需要动态加载扩展（省掉 dl 依赖），其余保持完整 SQL 能力。
. "$(dirname "$0")/_common.sh"

# 1) 从官方下载页取最新 amalgamation（链接形如 2026/sqlite-amalgamation-3530400.zip）
REL=$(latest_from_listing "https://sqlite.org/download.html" '[0-9]{4}/sqlite-amalgamation-[0-9]+\.zip')
[ -z "$REL" ] && { echo "  ✗ sqlite3 拿不到版本"; exit 0; }
URL="https://sqlite.org/$REL"

# 2) 下载 + 解压（取 sqlite3.c / shell.c / 头文件）
if [ ! -f /tmp/build/sqlite/sqlite3.c ]; then
  mkdir -p /tmp/build/sqlite
  curl -fsSL --max-time 300 -o /tmp/sq.zip "$URL" 2>/dev/null \
    || { echo "  ✗ sqlite3 下载失败"; exit 0; }
  rm -rf /tmp/build/sq-tmp; mkdir -p /tmp/build/sq-tmp
  unzip -qo /tmp/sq.zip -d /tmp/build/sq-tmp 2>/dev/null \
    || { echo "  ✗ sqlite3 解压失败"; exit 0; }
  find /tmp/build/sq-tmp -name 'sqlite3.c' -exec cp {} /tmp/build/sqlite/ \; 2>/dev/null
  find /tmp/build/sq-tmp -name 'shell.c'   -exec cp {} /tmp/build/sqlite/ \; 2>/dev/null
  find /tmp/build/sq-tmp -name 'sqlite3.h' -exec cp {} /tmp/build/sqlite/ \; 2>/dev/null
fi
[ -f /tmp/build/sqlite/sqlite3.c ] || { echo "  ✗ sqlite3 源码缺失"; exit 0; }

# 3) 编译（全静态 + 裁剪；-lm 数学库、-lpthread 线程支持）
#    注意：编译在子 shell 里做，install_verified 在外层跑（其 OUT 是相对路径）
( cd /tmp/build/sqlite \
  && $CROSS_CC -Os -static -DSQLITE_OMIT_LOAD_EXTENSION -o sqlite3 shell.c sqlite3.c -lm -lpthread >/tmp/m-sq 2>&1 \
  && cp sqlite3 /tmp/build/sqlite.bin ) \
  && install_verified /tmp/build/sqlite.bin sqlite3 \
  || echo "  ✗ sqlite3: $(grep -iE 'error' /tmp/m-sq 2>/dev/null | head -1 | cut -c1-110)"
