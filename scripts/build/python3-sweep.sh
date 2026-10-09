#!/bin/sh
# =============================================================================
# python3-sweep.sh —— 自解压壳 python3 终验：全量导入 + 功能抽查
#   用法: [PY3_QEMU=qemu-aarch64-static] sh scripts/build/python3-sweep.sh <python3单文件路径>
#         参数为 tools/python3/<arch>/python3 本体；跨架构时用 PY3_QEMU 指定 qemu。
# =============================================================================
set -eu
P="${1:?用法: python3-sweep.sh <python3单文件路径>}"
[ -f "$P" ] || { echo "✗ 找不到 $P"; exit 1; }
P="$(cd "$(dirname "$P")" && pwd)/$(basename "$P")"
if [ -n "${PY3_QEMU:-}" ]; then
  RUN="$PY3_QEMU $P"
else
  RUN="$P"
fi

$RUN - <<'PYEOF'
import importlib
mods = ("json csv re os sys io math cmath decimal fractions statistics random secrets "
        "hashlib hmac base64 binascii struct bisect heapq datetime time calendar zoneinfo "
        "pathlib tempfile shutil glob fnmatch subprocess threading queue asyncio "
        "concurrent.futures contextvars signal socket ssl select selectors http.client "
        "http.server urllib.request urllib.parse email.message sqlite3 logging traceback "
        "argparse getopt pickle copy copyreg dataclasses enum typing inspect dis opcode "
        "pprint difflib ipaddress platform sysconfig gzip tarfile zipfile socketserver "
        "mimetypes shlex string textwrap token tokenize uuid weakref warnings keyword "
        "linecache operator contextlib fileinput quopri locale getpass netrc pty tty "
        "configparser ctypes ctypes.util lzma bz2 multiprocessing unittest tomllib "
        "cProfile profile pstats pydoc doctest symtable ftplib xmlrpc.client "
        "xmlrpc.server plistlib runpy pickletools").split()
bad = []
for m in mods:
    try:
        importlib.import_module(m)
    except Exception as e:
        bad.append((m, str(e)[:70]))
print("IMPORT-BAD:", len(bad))
for m, e in bad:
    print("  -", m, "|", e)

print("== 功能抽查 ==")
import json, hashlib, zlib, bz2, lzma, sqlite3, ssl, subprocess, tarfile, zipfile, io, urllib.request, ctypes, uuid
print("json:", json.dumps({"a": [1, 2], "中": "文"}))
print("hash:", hashlib.sha256(b"x").hexdigest()[:10], "sha3:", hashlib.new("sha3_256").hexdigest()[:8], "crc:", zlib.crc32(b"x"))
c = sqlite3.connect(":memory:"); c.execute("create table t(a)"); c.execute("insert into t values(42)")
print("sqlite:", c.execute("select a from t").fetchone()[0], sqlite3.sqlite_version)
print("ssl:", ssl.OPENSSL_VERSION)
print("subprocess:", subprocess.run(["echo", "sp-ok"], capture_output=True, text=True).stdout.strip())
data = b"hello world " * 100
for name, mod in (("zlib", zlib), ("bz2", bz2), ("lzma", lzma)):
    assert mod.decompress(mod.compress(data)) == data
print("压缩往返: zlib/bz2/lzma ok")
print("ctypes:", ctypes.sizeof(ctypes.c_void_p), " uuid36:", len(str(uuid.uuid4())) == 36)
b = io.BytesIO()
with tarfile.open(fileobj=b, mode="w:xz"):
    pass
print("tarfile-xz:", len(b.getvalue()) > 0)
b2 = io.BytesIO()
with zipfile.ZipFile(b2, "w") as z:
    z.writestr("a.txt", "hi")
print("zipfile:", zipfile.ZipFile(b2).read("a.txt"))
from datetime import datetime
try:
    from zoneinfo import ZoneInfo
    print("zoneinfo:", datetime(2026, 10, 9, tzinfo=ZoneInfo("Asia/Shanghai")).utcoffset())
except Exception as e:
    print("zoneinfo FAIL:", e)
import multiprocessing as mp
def sq(x): return x * x
with mp.Pool(2) as p:
    assert p.map(sq, [2, 3]) == [4, 9]
print("multiprocessing ok")
try:
    r = urllib.request.urlopen("https://example.com", timeout=20)
    print("https:", r.status)
except Exception as e:
    print("https: FAIL", str(e)[:80])
print("DONE")
PYEOF
