# python3 —— 全静态 CPython 3.12（LibreSSL + sqlite3，白名单瘦身）

自编译（zig cc 交叉工具链）的 CPython 3.12.15：**全静态、零依赖**，解包即用；
链接 **LibreSSL**（含内嵌 CA，iSH 上**零配置直连 HTTPS**）与 **sqlite3**、zlib。
标准库按「Agent 常用白名单」抽取并以 -OO 字节码收进 `python312.zip`（仅 .pyc），
二进制经 UPX 压缩（4.2.4）；启动零告警、约 0.3s（iSH aarch64 实测）。

（本套件另有 `qjs`（JS 引擎）；Python 场景用本件。）

## 安装（整树件，install.sh 已内置处理）

```sh
sh scripts/install.sh            # 解包到 tools/python3/<arch>/tree 并软链 python3/python
python3 -V                       # → Python 3.12.15
```

## 推荐用法

```sh
# 1) 快速验证（含 TLS / sqlite）
python3 -c 'import ssl, sqlite3; print(ssl.OPENSSL_VERSION, sqlite3.sqlite_version)'

# 2) 零配置 HTTPS（内嵌 CA；iSH 上无需任何环境变量）
python3 -c 'import urllib.request as u; print(u.urlopen("https://example.com", timeout=20).status)'

# 3) 脚本与管道
python3 script.py
echo '{"a":1}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["a"])'

# 4) sqlite 快速查询
python3 -c 'import sqlite3; c=sqlite3.connect(":memory:"); print(c.execute("select 6*7").fetchone())'

# 5) pip（按需自举；为控体积未随包内置 ensurepip）
curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3 - --user

# 6) 版本 / 信息
python3 -VV
python3 -c 'import sys; print(sys.prefix); print(len(sys.builtin_module_names), "builtins")'
```

## 体量与构成（aarch64 实测）

| 件 | 大小 |
|---|---|
| `bin/python3.12`（UPX 后） | ≈ 4.5 MB |
| `lib/python312.zip`（stdlib，仅 .pyc） | ≈ 2.3 MB |
| 整树 tar.gz | ≈ 6.6 MB |

## 已内置的能力（摘要）

- 网络/解析：`socket` `ssl` `select` `selectors` `http.*` `urllib.*` `email` `html` `xml(etree/expat)` `json` `csv`
- 数据/系统：`sqlite3` `zlib` `hashlib`（含 sha3/blake2 内置实现）`hmac` `secrets` `struct` `decimal` `statistics`
- 并发：`threading` `asyncio` `concurrent.futures` `subprocess` `pty`
- 工具链：`argparse` `logging` `pathlib` `tempfile` `shutil` `tarfile` `zipfile` `gzip` `inspect` `dis` 等

## 未包含（有意裁剪）

`ctypes`（需 libffi）`readline` `curses` `tkinter` `_uuid` `lzma/bz2`（tarfile 的 xz/bz2 解码不可用，gz 正常）
`gdbm/dbm` `multiprocessing` 子包 `pydoc/idlelib/lib2to3/tests`。`_hashlib` 未含（hashlib 已由内置实现覆盖常用算法）。

## iSH 注意事项

- 完全静态 + LibreSSL 内嵌 CA：**无需** `SSL_CERT_FILE` / `OPENSSL_CONF` 等任何配置（历史上 `Groups=P-256` 之类补丁也不需要）。
- 启动 ~0.3s（含 UPX 解压）；需要行缓冲/彩显时配合 `faketty` 使用。
- 重装 rootfs 后用 `install.sh` 一键恢复；整树位于技能目录内（随 iCloud 同步）。

## 退出码

同 CPython：正常 0；未捕获异常 1；语法错误 2；以脚本返回值为准。

## 相关工具

`qjs`（JS 引擎）· `sqlite3`（独立 CLI）· `curl`（LibreSSL 静态）
