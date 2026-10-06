#!/bin/bash
# =============================================================================
# python3.sh —— 自编译全静态 CPython 3.12（zig cc；LibreSSL + sqlite3 + zlib）
#   产物：tools/python3/<arch>/python3.tar.gz（解包即用的整树，零依赖）
#   特性：全静态 / LibreSSL（iSH 适配补丁 + 内嵌 CA，零配置 HTTPS）/ sqlite3
#         白名单瘦身（-OO 字节码、仅 .pyc 进 zip）/ UPX；启动零警告
# 用法：ARCH=arm64|amd64 bash scripts/build/python3.sh
# 依赖：zig / curl / make / patch / unzip / ar / zip / upx / 宿主 python3.12
#       （aarch64 构建需要 qemu-user binfmt 以执行目标架构 Python）
# =============================================================================
set -euo pipefail

ARCH="${ARCH:?用法: ARCH=arm64|amd64 bash scripts/build/python3.sh}"
case "$ARCH" in
  amd64) TGT=x86_64-linux-musl;  STRIP=strip; MULTIARCH=x86_64-linux-gnu ;;
  arm64) TGT=aarch64-linux-musl; STRIP=aarch64-linux-gnu-strip; MULTIARCH=aarch64-linux-gnu ;;
  *) echo "✗ 未知架构 $ARCH"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/scripts/build"
HOSTPY="${HOSTPY:-/usr/bin/python3.12}"
JOBS="${JOBS:-2}"
SRC="${SRC:-/tmp/py3-src}"
WORK="${WORK:-/tmp/py3-work-$ARCH}"
SLIM="${SLIM:-/tmp/python3-slim-$ARCH}"
OUTDIR="$ROOT/tools/python3/$ARCH"

PYVER=3.12.15
ZLIBV=1.3.1
LSVER=4.3.3

fetch() { [ -f "$SRC/$1" ] || curl -fL --retry 3 -o "$SRC/$1" "$2"; }
mkdir -p "$SRC" "$WORK" "$OUTDIR"

echo "=== [$ARCH] 0/8 拉取源码 ==="
fetch "Python-$PYVER.tgz"      "https://www.python.org/ftp/python/$PYVER/Python-$PYVER.tgz"
fetch "zlib-$ZLIBV.tar.gz"     "https://github.com/madler/zlib/releases/download/v$ZLIBV/zlib-$ZLIBV.tar.gz"
fetch "libressl-$LSVER.tar.gz" "https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-$LSVER.tar.gz"
if [ ! -f "$SRC/sqlite.zip" ]; then
  U=$(curl -fsS --max-time 60 https://sqlite.org/download.html | grep -oE '20[0-9]{2}/sqlite-amalgamation-[0-9]+\.zip' | head -1)
  [ -n "$U" ] || { echo "✗ 拿不到 sqlite 版本"; exit 1; }
  curl -fL --retry 3 -o "$SRC/sqlite.zip" "https://sqlite.org/$U"
fi
for f in libressl-ishfix.patch gen-embed.sh libressl-min.cnf; do
  [ -f "$HERE/$f" ] || { echo "✗ 缺 $HERE/$f"; exit 1; }
done

echo "=== [$ARCH] 1/8 zlib（目标架构静态库）==="
if [ ! -f "$WORK/zlib-prefix/lib/libz.a" ]; then
  rm -rf "$WORK/zlib"; mkdir -p "$WORK/zlib"; cd "$WORK/zlib"
  tar xzf "$SRC/zlib-$ZLIBV.tar.gz" --strip-components=1
  CFLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables" CC="zig cc -target $TGT" ./configure --static --prefix="$WORK/zlib-prefix" > zlog 2>&1
  make -j"$JOBS" >> zlog 2>&1
  make install >> zlog 2>&1
fi

echo "=== [$ARCH] 2/8 sqlite3（amalgamation 静态库 + pkgconfig）==="
if [ ! -f "$WORK/sqlite-prefix/lib/libsqlite3.a" ]; then
  rm -rf "$WORK/sqlite"; mkdir -p "$WORK/sqlite"; cd "$WORK/sqlite"
  unzip -q "$SRC/sqlite.zip"
  cd sqlite-amalgamation-*
  zig cc -target "$TGT" -Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -c sqlite3.c -o sqlite3.o
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

echo "=== [$ARCH] 3/8 LibreSSL（iSH 适配补丁 + 内嵌 CA）==="
if [ ! -f "$WORK/libressl-prefix/lib/libssl.a" ]; then
  rm -rf "$WORK/libressl"; mkdir -p "$WORK/libressl"; cd "$WORK/libressl"
  tar xzf "$SRC/libressl-$LSVER.tar.gz" --strip-components=1
  patch -p1 < "$HERE/libressl-ishfix.patch"
  sh "$HERE/gen-embed.sh" /etc/ssl/certs/ca-certificates.crt "$HERE/libressl-min.cnf"
  CC="zig cc -target $TGT" CFLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables" ./configure --host="$TGT" --build=x86_64-linux-gnu \
      --prefix="$WORK/libressl-prefix" --disable-shared --enable-static \
      --with-openssldir=/etc/ssl > llog 2>&1
  make -j"$JOBS" >> llog 2>&1
  make install >> llog 2>&1
fi

echo "=== [$ARCH] 4/8 CPython 源码修补 ==="
rm -rf "$WORK/python"; mkdir -p "$WORK/python"; cd "$WORK/python"
tar xzf "$SRC/Python-$PYVER.tgz" --strip-components=1
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
for name in _ctypes _uuid _lzma _bz2 _gdbm _dbm _ndbm _curses _curses_panel readline _tkinter nis ossaudiodev _crypt _lsprof audioop xxlimited xxlimited_35 _xxsubinterpreters _xxinterpchannels; do
  sed -i -E "s|^(@[A-Z0-9_]+@)?${name}[[:space:]]|#\\1${name} |" Modules/Setup.stdlib.in
done
for name in _ssl _hashlib _sqlite3; do
  sed -i -E "s|^#(@[A-Z0-9_]+@)${name}[[:space:]]|\\1${name} |" Modules/Setup.stdlib.in
done
sed -i 's|^\*shared\*$|*static*|' Modules/Setup.stdlib.in

echo "=== [$ARCH] 5/8 configure ==="
mkdir -p "$WORK/python/build"; cd "$WORK/python/build"
PKG_CONFIG_PATH="$WORK/sqlite-prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
ac_cv_buggy_getaddrinfo=no ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no \
CC="zig cc -target $TGT" CFLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables" LDFLAGS="-static -Wl,--gc-sections" \
../configure --host="$TGT" --build=x86_64-linux-gnu \
    --with-build-python="$HOSTPY" \
    --with-openssl="$WORK/libressl-prefix" --with-openssl-rpath=no \
    --disable-shared --without-ensurepip --disable-test-modules \
    --prefix=/usr/local > cfg.log 2>&1
# 5.1 configure 后修补（生成物层）
sed -i 's|S\["MODULE_BUILDTYPE"\]="shared"|S["MODULE_BUILDTYPE"]="static"|' config.status
sed -i "s|MODULE_ZLIB_CFLAGS=|MODULE_ZLIB_CFLAGS=-I$WORK/zlib-prefix/include |; s|MODULE_ZLIB_LDFLAGS=-lz|MODULE_ZLIB_LDFLAGS=-L$WORK/zlib-prefix/lib -lz |" config.status
sed -i "s|MODULE_BINASCII_CFLAGS=-DUSE_ZLIB_CRC32 |MODULE_BINASCII_CFLAGS=|; s|MODULE_BINASCII_LDFLAGS=-lz|MODULE_BINASCII_LDFLAGS=|" config.status
# 5.2 sysconfigdata（宿主机 Python 生成 + 改名 linux_<multiarch> + 全落位）
_PYTHON_PROJECT_BASE="$WORK/python/build" "$HOSTPY" -S -m sysconfig --generate-posix-vars > scl.log 2>&1 || true
g=$(find build -name "_sysconfigdata*.py" 2>/dev/null | head -1)
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

echo "=== [$ARCH] 6/8 构建 + 安装 ==="
make -j"$JOBS" > make.log 2>&1
make install DESTDIR="$WORK/inst" > inst.log 2>&1
FULL="$WORK/inst/usr/local"
LIB_SRC="$FULL/lib/python3.12"
PYBIN="$FULL/bin/python3.12"
[ -x "$PYBIN" ] || { echo "✗ 安装产物缺失 $PYBIN"; exit 1; }

echo "=== [$ARCH] 7/8 白名单瘦身（-OO 字节码 + 仅 .pyc 进 zip）==="
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT INT TERM

WHITELIST_DIRS="encodings importlib collections re json asyncio http urllib email logging sqlite3 concurrent html xml zipfile zoneinfo"
for d in $WHITELIST_DIRS; do
    if [ -d "$LIB_SRC/$d" ]; then cp -rp "$LIB_SRC/$d" "$STAGE/"; else echo "  ⚠ 缺目录 $d"; fi
done

WHITELIST_FILES="
abc.py _collections_abc.py codecs.py contextlib.py contextvars.py copy.py copyreg.py
dataclasses.py enum.py functools.py genericpath.py heapq.py io.py keyword.py linecache.py
operator.py os.py posixpath.py ntpath.py pathlib.py reprlib.py stat.py string.py struct.py
textwrap.py token.py tokenize.py traceback.py types.py typing.py warnings.py weakref.py
site.py _sitebuiltins.py base64.py hashlib.py hmac.py secrets.py random.py socket.py ssl.py
selectors.py uuid.py calendar.py quopri.py bisect.py datetime.py subprocess.py threading.py
queue.py signal.py tempfile.py shutil.py fnmatch.py glob.py gzip.py fileinput.py shlex.py
mimetypes.py numbers.py csv.py argparse.py getopt.py pickle.py tarfile.py zipfile.py
socketserver.py sysconfig.py statistics.py platform.py pprint.py difflib.py ipaddress.py
inspect.py dis.py opcode.py decimal.py fractions.py
locale.py getpass.py netrc.py configparser.py pty.py tty.py stringprep.py
_weakrefset.py _compat_pickle.py _compression.py gettext.py ast.py
"
for f in $WHITELIST_FILES; do
    if [ -f "$LIB_SRC/$f" ]; then cp -p "$LIB_SRC/$f" "$STAGE/"; else echo "  ⚠ 缺文件 $f"; fi
done
cp -p "$LIB_SRC"/_sysconfigdata*.py "$STAGE/" 2>/dev/null || echo "  ⚠ 缺 _sysconfigdata*.py"

find "$STAGE" -type d \( -name "__pycache__" -o -name "test" -o -name "tests" \) -prune -exec rm -rf {} +
PYTHONNODEBUGRANGES=1 "$PYBIN" -OO -m compileall -b -q "$STAGE"
find "$STAGE" -type f -name "*.py" -delete

rm -rf "$SLIM"
mkdir -p "$SLIM/bin" "$SLIM/lib/python3.12/site-packages"
cp -p "$PYBIN" "$SLIM/bin/python3.12"
ln -sf python3.12 "$SLIM/bin/python3"
( cd "$STAGE" && zip -q -r -9 "$SLIM/lib/python312.zip" . )

echo "=== [$ARCH] 8/8 strip + UPX + 单文件组装 ==="
("$STRIP" --strip-debug "$SLIM/bin/python3.12" 2>/dev/null) || strip --strip-debug "$SLIM/bin/python3.12" 2>/dev/null || true

if [ "${UPX:-1}" = 1 ]; then
  if command -v upx >/dev/null 2>&1; then
    upx --best -q "$SLIM/bin/python3.12" || { echo "✗ UPX 失败"; exit 1; }
    if ! "$SLIM/bin/python3.12" -V >/dev/null 2>&1; then
      echo "✗ UPX 后无法运行（缺 qemu? 或压坏）"; exit 1
    fi
  else
    echo "  ⚠ 未找到 upx（跳过压缩，体积将明显变大）"
  fi
fi

ZIP="$SLIM/lib/python312.zip"
if command -v advzip >/dev/null 2>&1; then
  B=$(wc -c < "$ZIP")
  advzip -z4 "$ZIP" >/dev/null 2>&1 || true
  echo "  zip 再压: $B -> $(wc -c < "$ZIP")"
else
  echo "  ⚠ 未找到 advzip（跳过 zopfli 再压；CI 应预装 advancecomp）"
fi

# 组装单文件：UPX 后的二进制 + 追加 zip（getpath 补丁已把自身加入 sys.path）
mkdir -p "$OUTDIR"
cat "$SLIM/bin/python3.12" "$ZIP" > "$OUTDIR/python3"
chmod +x "$OUTDIR/python3"
rm -f "$OUTDIR/python3.tar.gz"

# 硬校验①：零告警
W=$("$OUTDIR/python3" -c 'pass' 2>&1) || true
if [ -n "$W" ]; then
  echo "✗ 启动存在告警，拒绝交付："; echo "$W" | head -5; exit 1
fi
# 硬校验②：功能冒烟（TLS + sqlite）
OUT=$("$OUTDIR/python3" -c 'import json, ssl, sqlite3, urllib.request as u; print(u.urlopen("https://example.com", timeout=20).status)' 2>&1) || true
case "$OUT" in
  *200*) echo "  冒烟: $OUT" ;;
  *) echo "✗ 冒烟失败：$OUT"; exit 1 ;;
esac

cp "$OUTDIR/python3" "/tmp/python3-$ARCH-single"
echo "=== [$ARCH] 完成（单文件）==="
ls -la "$OUTDIR/python3" | awk '{print $5, $NF}'
sha256sum "$OUTDIR/python3"
