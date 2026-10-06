#!/bin/sh
# =============================================================================
# python3-sweep.sh —— CPython 整树验收：全量导入 + 功能抽查
#   用法: sh scripts/build/python3-sweep.sh <tree_prefix>
#          （tree_prefix/bin/python3 必须存在；跨架构时需 qemu binfmt）
# =============================================================================
set -eu
TREE="${1:?用法: python3-sweep.sh <tree_prefix>}"
P="$TREE/bin/python3"
[ -x "$P" ] || P="$TREE/bin/python3.12"
[ -x "$P" ] || { echo "✗ 找不到 $TREE/bin/python3"; exit 1; }

"$P" - <<'PYEOF'
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
        "configparser").split()
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
import json, hashlib, zlib, sqlite3, ssl, subprocess, tarfile, zipfile, io, urllib.request
print("json:", json.dumps({"a": [1, 2], "中": "文"}))
print("hash:", hashlib.sha256(b"x").hexdigest()[:10], "sha3:", hashlib.new("sha3_256").hexdigest()[:8], "crc:", zlib.crc32(b"x"))
c = sqlite3.connect(":memory:"); c.execute("create table t(a)"); c.execute("insert into t values(42)")
print("sqlite:", c.execute("select a from t").fetchone()[0], sqlite3.sqlite_version)
print("ssl:", ssl.OPENSSL_VERSION)
print("subprocess:", subprocess.run(["echo", "sp-ok"], capture_output=True, text=True).stdout.strip())
b = io.BytesIO()
with tarfile.open(fileobj=b, mode="w:gz"):
    pass
print("tarfile-gz:", len(b.getvalue()) > 0)
b2 = io.BytesIO()
with zipfile.ZipFile(b2, "w") as z:
    z.writestr("a.txt", "hi")
print("zipfile:", zipfile.ZipFile(b2).read("a.txt"))
try:
    r = urllib.request.urlopen("https://example.com", timeout=20)
    print("https:", r.status)
except Exception as e:
    print("https: FAIL", str(e)[:80])
print("DONE")
PYEOF
