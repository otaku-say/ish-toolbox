#!/bin/bash
# =============================================================================
# python3.sh —— 自编译【动态 musl】CPython 3.12 → 自解压壳单文件
#   产物：tools/python3/<arch>/python3（[静态壳][xz(BCJ) 载荷][72B 尾部]；首次运行解压到 /tmp）
#   载荷：动态 musl / LibreSSL（内嵌 CA，零配置 HTTPS）/ sqlite3 / zlib / ctypes / lzma / bz2
#         / uuid / multiprocessing / unittest / zoneinfo（内嵌 tzdata）/ 完整模块白名单（-OO）
#   用法：ARCH=arm64|amd64 bash scripts/build/python3.sh
#        （工具链 / xz / xz-embedded 由 dyn-common.sh 自动准备；arm64 运行校验需 qemu + musl loader）
# =============================================================================
set -euo pipefail

# 失败取证：静默区（configure/make 输出已重定向）失败时打印相关日志尾部
trap 'rc=$?; echo "✗ 构建失败（line $LINENO rc=$rc）"; for f in llog zlog make.log inst.log scl.log cfg.log; do [ -f "$f" ] && { echo "==== tail $f ===="; tail -n 40 "$f" | cut -c1-220; }; done; exit $rc' ERR

ARCH="${ARCH:?用法: ARCH=arm64|amd64 bash scripts/build/python3.sh}"
case "$ARCH" in
  arm64) TGT=aarch64-linux-musl; MULTIARCH=aarch64-linux-musl
         CC_TARGET="${CC_TARGET:-/opt/musl-a64/bin/aarch64-linux-gcc}"
         STRIP="${STRIP:-/opt/musl-a64/bin/aarch64-linux-strip}"
         QEMU_RUN="${QEMU_RUN:-qemu-aarch64-static}" ;;
  amd64) TGT=x86_64-linux-musl; MULTIARCH=x86_64-linux-musl
         CC_TARGET="${CC_TARGET:-/opt/musl-x64/bin/x86_64-linux-gcc}"
         STRIP="${STRIP:-/opt/musl-x64/bin/x86_64-linux-strip}"
         QEMU_RUN="${QEMU_RUN:-}" ;;
  *) echo "✗ 未知架构 $ARCH"; exit 1 ;;
esac

# 公共构件（工具链 / xz / xz-embedded / 壳）；缺失自动准备（幂等）
. "$(cd "$(dirname "$0")" && pwd)/dyn-common.sh"
dyn_setup
[ -x "$CC_TARGET" ] || { echo "✗ 缺交叉编译器：$CC_TARGET"; exit 1; }
[ -x "$STRIP" ] || { echo "✗ 缺 strip：$STRIP"; exit 1; }
if [ -n "$QEMU_RUN" ]; then command -v "$QEMU_RUN" >/dev/null 2>&1 || { echo "✗ 缺 $QEMU_RUN"; exit 1; }; fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/scripts/build"
HOSTPY="${HOSTPY:-/usr/bin/python3.12}"
[ -x "$HOSTPY" ] || HOSTPY="$(command -v python3.12 2>/dev/null || true)"
[ -x "$HOSTPY" ] || { echo "✗ 缺宿主 python3.12（--with-build-python 需要；可用 HOSTPY=/path 指定）"; exit 1; }
JOBS="${JOBS:-2}"
SRC="${SRC:-/tmp/py3-src}"
WORK="${WORK:-/tmp/py3dyn-work-$ARCH}"
SLIM="${SLIM:-/tmp/py3dyn-slim-$ARCH}"
OUTDIR="${OUTDIR:-$ROOT/tools/python3/$ARCH}"

PYVER=3.12.15
ZLIBV=1.3.1
LSVER=4.3.3
FFIVER=3.4.6
XZV=5.6.4
BZ2V=1.0.8
ULV=2.40.2

fetch() { [ -f "$SRC/$1" ] || curl -fL --retry 3 -o "$SRC/$1" "$2"; }
mkdir -p "$SRC" "$WORK" "$OUTDIR"

echo "=== [$ARCH] 0/10 拉取源码 ==="
fetch "Python-$PYVER.tgz"      "https://www.python.org/ftp/python/$PYVER/Python-$PYVER.tgz"
fetch "zlib-$ZLIBV.tar.gz"     "https://github.com/madler/zlib/releases/download/v$ZLIBV/zlib-$ZLIBV.tar.gz"
fetch "libressl-$LSVER.tar.gz" "https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-$LSVER.tar.gz"
fetch "libffi-$FFIVER.tar.gz"  "https://github.com/libffi/libffi/releases/download/v$FFIVER/libffi-$FFIVER.tar.gz"
fetch "xz-$XZV.tar.gz"         "https://tukaani.org/xz/xz-$XZV.tar.gz"
fetch "bzip2-$BZ2V.tar.gz"     "https://sourceware.org/pub/bzip2/bzip2-$BZ2V.tar.gz"
fetch "util-linux-$ULV.tar.xz" "https://www.kernel.org/pub/linux/utils/util-linux/v2.40/util-linux-$ULV.tar.xz"
if [ ! -f "$SRC/tzdata.whl" ]; then
  TU=$(curl -fsS --max-time 60 https://pypi.org/simple/tzdata/ | grep -oE 'https://files[.]pythonhosted[.]org/[^"]*tzdata-[0-9.]+-py2[.]py3-none-any[.]whl' | tail -1)
  [ -n "$TU" ] || echo "  ⚠ tzdata 链接解析失败（跳过内嵌）"
  [ -n "$TU" ] && curl -fL --retry 3 -o "$SRC/tzdata.whl" "$TU"
fi
if [ ! -f "$SRC/sqlite.zip" ]; then
  U=$(curl -fsS --max-time 60 https://sqlite.org/download.html | grep -oE '20[0-9]{2}/sqlite-amalgamation-[0-9]+\.zip' | sed -n '1p')
  [ -n "$U" ] || { echo "✗ 拿不到 sqlite 版本"; exit 1; }
  curl -fL --retry 3 -o "$SRC/sqlite.zip" "https://sqlite.org/$U"
fi
for f in libressl-ishfix.patch gen-embed.sh libressl-min.cnf; do
  [ -f "$HERE/$f" ] || { echo "✗ 缺 $HERE/$f"; exit 1; }
done

echo "=== [$ARCH] 1/10 zlib（目标架构静态库）==="
if [ ! -f "$WORK/zlib-prefix/lib/libz.a" ]; then
  rm -rf "$WORK/zlib"; mkdir -p "$WORK/zlib"; cd "$WORK/zlib"
  tar xzf "$SRC/zlib-$ZLIBV.tar.gz" --strip-components=1
  CFLAGS="-Os -fPIC -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables" CC="$CC_TARGET" ./configure --static --prefix="$WORK/zlib-prefix" > zlog 2>&1
  make -j"$JOBS" >> zlog 2>&1
  make install >> zlog 2>&1
fi

echo "=== [$ARCH] 2/10 sqlite3（amalgamation 静态库 + pkgconfig）==="
if [ ! -f "$WORK/sqlite-prefix/lib/libsqlite3.a" ]; then
  rm -rf "$WORK/sqlite"; mkdir -p "$WORK/sqlite"; cd "$WORK/sqlite"
  unzip -q "$SRC/sqlite.zip"
  cd sqlite-amalgamation-*
  "$CC_TARGET" -Os -fPIC -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -c sqlite3.c -o sqlite3.o
  ar rcs libsqlite3.a sqlite3.o
  mkdir -p "$WORK/sqlite-prefix/include" "$WORK/sqlite-prefix/lib/pkgconfig"
  cp sqlite3.h sqlite3ext.h "$WORK/sqlite-prefix/include/"
  cp libsqlite3.a "$WORK/sqlite-prefix/lib/"
  SQVER=$(grep -m1 '#define SQLITE_VERSION ' sqlite3.h | awk '{print $3}' | tr -d '"')
  cat > "$WORK/sqlite-prefix/lib/pkgconfig/sqlite3.pc" <<EOF
prefix=$WORK/sqlite-prefix
Name: sqlite3
Description: SQLite static (zig cc)
Version: ${SQVER:-3.53.4}
Cflags: -I\${prefix}/include
Libs: -L\${prefix}/lib -lsqlite3
EOF
fi

echo "=== [$ARCH] 2.5/10 依赖库（libffi / liblzma / libbz2 静态）==="
DEPS="$WORK/deps-prefix"
if [ ! -f "$DEPS/lib/libffi.a" ] || [ ! -f "$DEPS/lib/liblzma.a" ] || [ ! -f "$DEPS/lib/libbz2.a" ] || [ ! -f "$DEPS/lib/libuuid.a" ]; then
  mkdir -p "$DEPS/include" "$DEPS/lib/pkgconfig"
  PATH_SAVE="$PATH"; export PATH="$(dirname "$CC_TARGET"):$PATH"

  if [ ! -f "$DEPS/lib/libffi.a" ]; then
    rm -rf "$WORK/libffi"; mkdir -p "$WORK/libffi"; cd "$WORK/libffi"
    tar xzf "$SRC/libffi-$FFIVER.tar.gz" --strip-components=1
    CC="$CC_TARGET" CFLAGS="-Os -fPIC -ffunction-sections -fdata-sections" \
      ./configure --host="$TGT" --build=x86_64-linux-gnu --disable-shared --enable-static \
      --disable-docs --disable-multi-os-directory --prefix="$DEPS" --libdir="$DEPS/lib" > flog 2>&1
    make -j"$JOBS" >> flog 2>&1 && make install >> flog 2>&1
    [ -f "$DEPS/lib/libffi.a" ] || { mkdir -p "$DEPS/lib"; cp -f "$DEPS"/lib64/libffi.a "$DEPS/lib/" 2>/dev/null || true; }
  fi

  if [ ! -f "$DEPS/lib/liblzma.a" ]; then
    rm -rf "$WORK/xz"; mkdir -p "$WORK/xz"; cd "$WORK/xz"
    tar xzf "$SRC/xz-$XZV.tar.gz" --strip-components=1
    CC="$CC_TARGET" CFLAGS="-Os -fPIC -ffunction-sections -fdata-sections" \
      ./configure --host="$TGT" --build=x86_64-linux-gnu --disable-shared --enable-static \
      --disable-nls --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo \
      --disable-lzma-links --disable-scripts --disable-doc --prefix="$DEPS" --libdir="$DEPS/lib" > xlog 2>&1
    make -j"$JOBS" >> xlog 2>&1 && make install >> xlog 2>&1
  fi

  if [ ! -f "$DEPS/lib/libbz2.a" ]; then
    rm -rf "$WORK/bzip2"; mkdir -p "$WORK/bzip2"; cd "$WORK/bzip2"
    tar xzf "$SRC/bzip2-$BZ2V.tar.gz" --strip-components=1
    make -j"$JOBS" libbz2.a CC="$CC_TARGET" CFLAGS="-Os -fPIC -ffunction-sections -fdata-sections -Wall -D_FILE_OFFSET_BITS=64" > blog 2>&1
    cp libbz2.a "$DEPS/lib/" && cp bzlib.h "$DEPS/include/"
  fi

  if [ ! -f "$DEPS/lib/libuuid.a" ]; then
    rm -rf "$WORK/util-linux"; mkdir -p "$WORK/util-linux"; cd "$WORK/util-linux"
    tar xf "$SRC/util-linux-$ULV.tar.xz" --strip-components=1
    CC="$CC_TARGET" CFLAGS="-Os -fPIC -ffunction-sections -fdata-sections" \
      ./configure --host="$TGT" --build=x86_64-linux-gnu --disable-shared --enable-static \
      --disable-all-programs --enable-libuuid --disable-nls --without-python \
      --prefix="$DEPS" --libdir="$DEPS/lib" > ulog 2>&1
    make -j"$JOBS" >> ulog 2>&1 && make install >> ulog 2>&1
    [ -f "$DEPS/lib/libuuid.a" ] || { mkdir -p "$DEPS/lib"; cp -f "$DEPS"/lib64/libuuid.a "$DEPS/lib/" 2>/dev/null || true; }
  fi

  [ -f "$DEPS/lib/pkgconfig/libffi.pc" ] || cat > "$DEPS/lib/pkgconfig/libffi.pc" <<EOF
prefix=$DEPS
Name: libffi
Description: libffi (static)
Version: $FFIVER
Cflags: -I\${prefix}/include
Libs: -L\${prefix}/lib -lffi
EOF
  [ -f "$DEPS/lib/pkgconfig/liblzma.pc" ] || cat > "$DEPS/lib/pkgconfig/liblzma.pc" <<EOF
prefix=$DEPS
Name: liblzma
Description: liblzma (static)
Version: $XZV
Cflags: -I\${prefix}/include
Libs: -L\${prefix}/lib -llzma
EOF
  [ -f "$DEPS/lib/pkgconfig/bzip2.pc" ] || cat > "$DEPS/lib/pkgconfig/bzip2.pc" <<EOF
prefix=$DEPS
Name: bzip2
Description: bzip2 (static)
Version: $BZ2V
Cflags: -I\${prefix}/include
Libs: -L\${prefix}/lib -lbz2
EOF
  [ -f "$DEPS/lib/pkgconfig/uuid.pc" ] || cat > "$DEPS/lib/pkgconfig/uuid.pc" <<EOF
prefix=$DEPS
Name: uuid
Description: libuuid (static)
Version: $ULV
Cflags: -I\${prefix}/include
Libs: -L\${prefix}/lib -luuid
EOF
  export PATH="$PATH_SAVE"
fi

# 依赖库终检（失败即停）
[ -f "$DEPS/lib/libffi.a" ] || { echo "✗ libffi 缺失（$DEPS/lib）"; exit 1; }
[ -f "$DEPS/lib/liblzma.a" ] || { echo "✗ liblzma 缺失（$DEPS/lib）"; exit 1; }
[ -f "$DEPS/lib/libbz2.a" ] || { echo "✗ libbz2 缺失（$DEPS/lib）"; exit 1; }
[ -f "$DEPS/lib/libuuid.a" ] || { echo "✗ libuuid 缺失（$DEPS/lib）"; exit 1; }

echo "=== [$ARCH] 3/10 LibreSSL（iSH 适配补丁 + 内嵌 CA）==="
if [ ! -f "$WORK/libressl-prefix/lib/libssl.a" ]; then
  rm -rf "$WORK/libressl"; mkdir -p "$WORK/libressl"; cd "$WORK/libressl"
  tar xzf "$SRC/libressl-$LSVER.tar.gz" --strip-components=1
  patch -p1 < "$HERE/libressl-ishfix.patch"
  sh "$HERE/gen-embed.sh" /etc/ssl/certs/ca-certificates.crt "$HERE/libressl-min.cnf"
  CC="$CC_TARGET" CFLAGS="-Os -fPIC -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables" ./configure --host="$TGT" --build=x86_64-linux-gnu \
      --prefix="$WORK/libressl-prefix" --disable-shared --enable-static \
      --with-openssldir=/etc/ssl > llog 2>&1
  make -j"$JOBS" >> llog 2>&1
  # 安装走 DESTDIR 侧舱：避免 install-exec-hook 往 /etc/ssl 写（CI 非 root 会 Permission denied）
  make install DESTDIR="$WORK/lside" >> llog 2>&1
  rm -rf "$WORK/lside/etc"
  mkdir -p "$WORK/libressl-prefix"
  cp -a "$WORK/lside$WORK/libressl-prefix/." "$WORK/libressl-prefix/"
  rm -rf "$WORK/lside"
fi

echo "=== [$ARCH] 4/10 CPython 源码修补 ==="
rm -rf "$WORK/python"; mkdir -p "$WORK/python"; cd "$WORK/python"
tar xzf "$SRC/Python-$PYVER.tgz" --strip-components=1
# 4.0 musl triplet 修正：上游仅在 build_os 为 musl 时改三元组；交叉编译（build=glibc→host=musl）
#     不触发，会让 SOABI 错成 -gnu、导致 musllinux 轮子的扩展后缀不匹配。让 host_os 也参与判定。
python3 - <<'PATCH_EOF'
for path in ("configure", "configure.ac"):
    s = open(path, encoding="utf-8").read()
    if 'case "$build_os:$host_os" in' in s:
        print("%s: 已补丁" % path); continue
    a = 'case "$build_os" in'
    assert s.count(a) == 1, "%s: anchor=%d" % (path, s.count(a))
    s = s.replace(a, 'case "$build_os:$host_os" in')
    b = "linux-musl*)"
    assert s.count(b) == 1, "%s: pattern=%d" % (path, s.count(b))
    s = s.replace(b, "*linux-musl*)")
    open(path, "w", encoding="utf-8").write(s)
    print("%s: musl 补丁完成" % path)
PATCH_EOF
grep -q 'build_os:$host_os' configure || { echo "✗ configure musl 补丁缺失"; exit 1; }
grep -q 'build_os:$host_os' configure.ac || { echo "✗ configure.ac musl 补丁缺失"; exit 1; }
# 4.1 getbuildinfo：去 __DATE__/__TIME__（zig cc 视为错误）
sed -i 's|#define DATE __DATE__|#define DATE "build"|; s|#define TIME __TIME__|#define TIME ""|' Modules/getbuildinfo.c
# 4.2 _ssl.c：LibreSSL 自带 X509_STORE_get1_objects → 屏蔽 CPython 旧版 fallback
sed -i 's|^#if OPENSSL_VERSION_NUMBER < 0x30300000L$|#if OPENSSL_VERSION_NUMBER < 0x30300000L \&\& !defined(LIBRESSL_VERSION_NUMBER)|' Modules/_ssl.c
# 4.3 getpath.py：静态布局适配（无 lib-dynload 不再告警；getpath 冻结进二进制）
sed -i 's|            exec_prefix = search_up(executable_dir, PLATSTDLIB_LANDMARK, test=isdir)|&\n        if not exec_prefix and executable_dir:\n            # iSH 适配：静态布局（无 lib-dynload）时降级为 stdlib 子目录地标\n            exec_prefix = search_up(executable_dir, STDLIB_SUBDIR, test=isdir)|' Modules/getpath.py
sed -i 's|        if not exec_prefix or not isdir(joinpath(exec_prefix, PLATSTDLIB_LANDMARK)):|        if not exec_prefix or (not isdir(joinpath(exec_prefix, PLATSTDLIB_LANDMARK)) and not isdir(joinpath(exec_prefix, STDLIB_SUBDIR))):|' Modules/getpath.py
# 4.3b 单文件变体：警告静默 + sys.path 自追加可执行文件
python3 - <<'PYEOF'
g = "Modules/getpath.py"
s = open(g, encoding="utf-8").read()
for o in ["warn('Could not find platform independent libraries <prefix>')",
          "warn('Could not find platform dependent libraries <exec_prefix>')",
          "warn('Consider setting $PYTHONHOME to <prefix>[:<exec_prefix>]')"]:
    s = s.replace(o, "pass  # iSH single-file")
old = ("    config['module_search_paths'] = pythonpath\n"
       "    config['module_search_paths_set'] = 1\n"
       "\n"
       "\n"
       "# ******************************************************************************\n"
       "# POSIX prefix/exec_prefix QUIRKS")
new = ("    if executable and executable not in pythonpath:\n"
       "        pythonpath.append(executable)\n"
       "    config['module_search_paths'] = pythonpath\n"
       "    config['module_search_paths_set'] = 1\n"
       "\n"
       "\n"
       "# ******************************************************************************\n"
       "# POSIX prefix/exec_prefix QUIRKS")
assert s.count(old) == 1, "self-append anchor"
s = s.replace(old, new)
open(g, "w", encoding="utf-8").write(s)
print("single-file getpath edits ok")
PYEOF
# 4.4 模块表：白名单外一律裁剪（模板层；保留 _ssl/_hashlib/_sqlite3/zlib）
for name in _gdbm _dbm _ndbm _curses _curses_panel readline _tkinter nis ossaudiodev _crypt audioop xxlimited xxlimited_35 _xxsubinterpreters _xxinterpchannels; do
  sed -i -E "s|^(@[A-Z0-9_]+@)?${name}[[:space:]]|#\\1${name} |" Modules/Setup.stdlib.in
done
for name in _ssl _hashlib _sqlite3 _ctypes _uuid _lzma _bz2 _lsprof; do
  sed -i -E "s|^#(@[A-Z0-9_]+@)${name}[[:space:]]|\\1${name} |" Modules/Setup.stdlib.in
done
sed -i 's|^\*shared\*$|*static*|' Modules/Setup.stdlib.in

echo "=== [$ARCH] 5/10 configure ==="
mkdir -p "$WORK/python/build"; cd "$WORK/python/build"
PKG_CONFIG_PATH="$WORK/sqlite-prefix/lib/pkgconfig:$WORK/deps-prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
ac_cv_buggy_getaddrinfo=no ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no \
CC="$CC_TARGET" CFLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables" \
LDFLAGS="-L$WORK/deps-prefix/lib -Wl,--gc-sections" CPPFLAGS="-I$WORK/deps-prefix/include" LIBS="-lffi -llzma -lbz2 -luuid" \
../configure --host="$TGT" --build=x86_64-linux-gnu \
    --with-build-python="$HOSTPY" \
    --with-openssl="$WORK/libressl-prefix" --with-openssl-rpath=no \
    --disable-shared --without-ensurepip --disable-test-modules \
    --prefix=/usr/local > cfg.log 2>&1
# 5.0 musl 三元组断言（SOABI/MULTIARCH 必须为 musl）
_SO=$(grep -m1 '^SOABI=' Makefile 2>/dev/null); echo "  $_SO"
case "$_SO" in *musl*) ;; *) echo "✗ SOABI 非 musl：$_SO"; exit 1 ;; esac
_MU=$(grep -m1 '^MULTIARCH=' Makefile 2>/dev/null); echo "  $_MU"
case "$_MU" in *musl*) ;; *) echo "✗ MULTIARCH 非 musl：$_MU"; exit 1 ;; esac
# 5.1 configure 后修补（生成物层）
sed -i 's|S\["MODULE_BUILDTYPE"\]="shared"|S["MODULE_BUILDTYPE"]="static"|' config.status
sed -i "s|MODULE_ZLIB_CFLAGS=|MODULE_ZLIB_CFLAGS=-I$WORK/zlib-prefix/include |; s|MODULE_ZLIB_LDFLAGS=-lz|MODULE_ZLIB_LDFLAGS=-L$WORK/zlib-prefix/lib -lz |" config.status
sed -i "s|MODULE_BINASCII_CFLAGS=-DUSE_ZLIB_CRC32 |MODULE_BINASCII_CFLAGS=|; s|MODULE_BINASCII_LDFLAGS=-lz|MODULE_BINASCII_LDFLAGS=|" config.status
# 5.1b 新依赖模块兜底：探测缺失时强制启用并注入链接参数
python3 - "$WORK/deps-prefix" <<'PYEOF'
import sys
deps = sys.argv[1]
BS = chr(92)
NL = BS + "n"
LF = chr(10)
s = open("config.status").read()
for mod, lib in (("MODULE__CTYPES", "ffi"), ("MODULE__LZMA", "lzma"), ("MODULE__BZ2", "bz2"), ("MODULE__UUID", "uuid")):
    if f"{mod}_STATE=missing" not in s:
        continue
    print(f"  [fix] {mod}: 探测缺失 -> 强制启用 (-l{lib})")
    s = s.replace(f"{mod}_STATE=missing", f"{mod}_STATE=yes")
    s = s.replace(f'S["{mod}_TRUE"]="#"', f'S["{mod}_TRUE"]=""')
    s = s.replace(f'S["{mod}_FALSE"]=""', f'S["{mod}_FALSE"]="#"')
    anchor = '"' + mod + "_STATE=yes" + NL + '"' + BS + LF
    ins = ('"' + mod + f"_CFLAGS=-I{deps}/include" + NL + '"' + BS + LF +
           '"' + mod + f"_LDFLAGS=-L{deps}/lib -l{lib}" + NL + '"' + BS + LF)
    if anchor in s and ins not in s:
        s = s.replace(anchor, anchor + ins, 1)
open("config.status", "w").write(s)
PYEOF
# 5.2 sysconfigdata（宿主机 Python 生成 + 改名 linux_<multiarch> + 全落位）
_PYTHON_PROJECT_BASE="$WORK/python/build" "$HOSTPY" -S -m sysconfig --generate-posix-vars > scl.log 2>&1 || true
g=$(find build -name "_sysconfigdata*.py" 2>/dev/null | sed -n '1p')
if [ -n "${g:-}" ]; then
  n="_sysconfigdata__linux_${MULTIARCH}.py"
  for d in build/lib.*; do [ -d "$d" ] && cp "$g" "$d/$n"; done
  mkdir -p "build/lib.linux-${MULTIARCH}"
  cp "$g" "build/lib.linux-${MULTIARCH}/$n"
  mkdir -p Lib
  cp "$g" "Lib/$n"
  cp "$g" "../Lib/$n"
fi
rm -f Makefile.pre ../Modules/Setup.stdlib

echo "=== [$ARCH] 6/10 构建 + 安装 ==="
make -j"$JOBS" > make.log 2>&1
make install DESTDIR="$WORK/inst" > inst.log 2>&1
FULL="$WORK/inst/usr/local"
LIB_SRC="$FULL/lib/python3.12"
PYBIN="$FULL/bin/python3.12"
[ -x "$PYBIN" ] || { echo "✗ 安装产物缺失 $PYBIN"; exit 1; }

echo "=== [$ARCH] 7/10 白名单瘦身（-OO 字节码 + 仅 .pyc 进 zip）==="
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT INT TERM

WHITELIST_DIRS="encodings importlib collections re json asyncio http urllib email logging sqlite3 concurrent html xml zipfile zoneinfo multiprocessing unittest tomllib ctypes xmlrpc"
for d in $WHITELIST_DIRS; do
    if [ -d "$LIB_SRC/$d" ]; then cp -rp "$LIB_SRC/$d" "$STAGE/"; else echo "  ⚠ 缺目录 $d"; fi
done

WHITELIST_FILES="
__future__.py _strptime.py pkgutil.py graphlib.py filecmp.py
abc.py _collections_abc.py codecs.py contextlib.py contextvars.py copy.py copyreg.py
dataclasses.py enum.py functools.py genericpath.py heapq.py io.py keyword.py linecache.py
operator.py os.py posixpath.py ntpath.py pathlib.py reprlib.py stat.py string.py struct.py
textwrap.py token.py tokenize.py traceback.py types.py typing.py warnings.py weakref.py
site.py _sitebuiltins.py base64.py hashlib.py hmac.py secrets.py random.py socket.py ssl.py
selectors.py uuid.py calendar.py quopri.py bisect.py datetime.py subprocess.py threading.py
queue.py signal.py tempfile.py shutil.py fnmatch.py glob.py gzip.py fileinput.py shlex.py
mimetypes.py numbers.py csv.py argparse.py getopt.py pickle.py tarfile.py
socketserver.py sysconfig.py statistics.py platform.py pprint.py difflib.py ipaddress.py
inspect.py dis.py opcode.py decimal.py fractions.py
locale.py getpass.py netrc.py configparser.py pty.py tty.py stringprep.py
_weakrefset.py _compat_pickle.py _compression.py gettext.py ast.py
_markupbase.py _threading_local.py colorsys.py optparse.py smtplib.py
py_compile.py compileall.py pickletools.py plistlib.py timeit.py tracemalloc.py
bdb.py cmd.py code.py codeop.py pdb.py cProfile.py pstats.py doctest.py lzma.py bz2.py symtable.py
profile.py pydoc.py rlcompleter.py runpy.py ftplib.py nturl2path.py
"
for f in $WHITELIST_FILES; do
    if [ -f "$LIB_SRC/$f" ]; then cp -p "$LIB_SRC/$f" "$STAGE/"; else echo "  ⚠ 缺文件 $f"; fi
done
cp -p "$LIB_SRC"/_sysconfigdata*.py "$STAGE/" 2>/dev/null || echo "  ⚠ 缺 _sysconfigdata*.py"
if [ -f "$SRC/tzdata.whl" ]; then
  rm -rf "$WORK/tzdata-x"; mkdir -p "$WORK/tzdata-x"
  (cd "$WORK/tzdata-x" && unzip -q "$SRC/tzdata.whl") || true
  if [ -d "$WORK/tzdata-x/tzdata" ]; then
    cp -rp "$WORK/tzdata-x/tzdata" "$STAGE/"
    echo "  内嵌 tzdata ✓"
  fi
fi

find "$STAGE" -type d \( -name "__pycache__" -o -name "test" -o -name "tests" \) -prune -exec rm -rf {} +
PYTHONNODEBUGRANGES=1 $QEMU_RUN "$PYBIN" -OO -m compileall -b -q "$STAGE"
find "$STAGE" -type f -name "*.py" -delete

rm -rf "$SLIM"
mkdir -p "$SLIM/bin" "$SLIM/lib/python3.12/site-packages"
cp -p "$PYBIN" "$SLIM/bin/python3.12"
ln -sf python3.12 "$SLIM/bin/python3"
( cd "$STAGE" && zip -q -r -9 "$SLIM/lib/python312.zip" . )

echo "=== [$ARCH] 8/10 strip + 动态单文件组装（壳的载荷源）==="
("$STRIP" --strip-debug "$SLIM/bin/python3.12" 2>/dev/null) || strip --strip-debug "$SLIM/bin/python3.12" 2>/dev/null || true

ZIP="$SLIM/lib/python312.zip"
if command -v advzip >/dev/null 2>&1; then
  B=$(wc -c < "$ZIP")
  advzip -z4 "$ZIP" >/dev/null 2>&1 || true
  echo "  zip 再压: $B -> $(wc -c < "$ZIP")"
else
  echo "  ⚠ 未找到 advzip（跳过 zopfli 再压；CI 应预装 advancecomp）"
fi

RAW="$WORK/final-raw-single"
cat "$SLIM/bin/python3.12" "$ZIP" > "$RAW"
chmod +x "$RAW"

# 硬校验①：零告警
W=$($QEMU_RUN "$RAW" -c 'pass' 2>&1) || true
if [ -n "$W" ]; then
  echo "✗ 启动存在告警，拒绝交付："; echo "$W" | head -5; exit 1
fi
# 硬校验②：功能冒烟（TLS + sqlite）
OUT=$($QEMU_RUN "$RAW" -c 'import json, ssl, sqlite3, urllib.request as u; print(u.urlopen("https://example.com", timeout=20).status)' 2>&1) || true
case "$OUT" in
  *200*) echo "  冒烟: $OUT" ;;
  *) echo "✗ 冒烟失败：$OUT"; exit 1 ;;
esac

echo "=== [$ARCH] 9/10 动态特性硬校验 ==="
SUF=$($QEMU_RUN "$RAW" -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))' 2>&1)
echo "  EXT_SUFFIX=$SUF"
case "$SUF" in *musl*) ;; *) echo "✗ EXT_SUFFIX 非 musl"; exit 1 ;; esac
MD=/tmp/py3dyn-mod; rm -rf "$MD"; mkdir -p "$MD"
cat > "$MD/tinymod.c" <<'TMEOF'
#include "Python.h"
static PyObject* answer(PyObject* s, PyObject* a){ return PyLong_FromLong(42); }
static PyMethodDef M[] = {{"answer", answer, METH_NOARGS, ""}, {NULL,NULL,0,NULL}};
static struct PyModuleDef D = { PyModuleDef_HEAD_INIT, "tinymod", "", -1, M };
PyMODINIT_FUNC PyInit_tinymod(void){ return PyModule_Create(&D); }
TMEOF
"$CC_TARGET" -shared -fPIC -I"$FULL/include/python3.12" "$MD/tinymod.c" -o "$MD/tinymod$SUF" || { echo "✗ tinymod 编译失败"; exit 1; }
OUTD=$($QEMU_RUN "$RAW" -c "import sys; sys.path.insert(0, '$MD'); import tinymod; print('dlopen-ok', tinymod.answer())" 2>&1)
case "$OUTD" in *dlopen-ok*42*) echo "  dlopen 硬校验: $OUTD" ;; *) echo "✗ dlopen 失败：$OUTD"; exit 1 ;; esac

echo "=== [$ARCH] 10/10 自解压壳打包（xz BCJ）+ 终验 ==="
STUB="$WORK/py3dyn-stub-$ARCH"
dyn_build_stub "$STUB"
mkdir -p "$OUTDIR"
rm -f "$OUTDIR/python3.raw" "$OUTDIR/python3.tar.gz" 2>/dev/null || true
dyn_package "$STUB" "$RAW" "$OUTDIR/python3" python3

rm -rf /tmp/.ish-py3dyn-*
V=$($QEMU_RUN "$OUTDIR/python3" --version 2>&1) || true
case "$V" in
  *"Python $PYVER"*) echo "  壳终验: $V" ;;
  *) echo "✗ 壳运行异常：$V"; exit 1 ;;
esac
MOD_OUT=$($QEMU_RUN "$OUTDIR/python3" -c 'import ctypes, lzma, bz2, uuid, zoneinfo, multiprocessing, unittest; print("shell-modules-ok")' 2>&1) || true
case "$MOD_OUT" in
  *shell-modules-ok*) echo "  壳模块终验: $MOD_OUT" ;;
  *) echo "✗ 壳模块终验失败：$MOD_OUT"; exit 1 ;;
esac

cp "$OUTDIR/python3" "/tmp/python3-$ARCH-single"
echo "=== [$ARCH] 完成（自解压壳单文件）==="
ls -la "$OUTDIR/python3" | awk '{print $5, $NF}'
sha256sum "$OUTDIR/python3"
