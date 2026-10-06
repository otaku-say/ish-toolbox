# python3 —— 全静态 CPython 3.12 单文件（LibreSSL + sqlite3）

自编译（zig cc）的 CPython 3.12.15 **单文件静态二进制**：一个文件、零依赖、放下即用；
链接 **LibreSSL**（内嵌 CA，iSH 上**零配置直连 HTTPS**）与 **sqlite3**、zlib。
标准库按「Agent 常用白名单」抽取为 -OO 字节码（去文档/断言、去调试范围），
zopfli 重压后**追加在二进制尾部**（自携带 zip，解释器自动加载）；主体经 UPX 压缩。
**约 5.5MB（arm64）单文件，iSH 启动约 0.27s**；CI 含硬校验（零告警 + 功能冒烟 + 全量导入）。

## 安装（单文件直装）

```sh
sh scripts/install.sh            # 落一个文件到 PATH，并给 python 别名
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
python3 -c 'import sys; print(len(sys.builtin_module_names), "builtins")'
```

## 体量（aarch64 实测）

| 件 | 大小 |
|---|---|
| 单文件（UPX 后二进制 + 追加 zip） | ≈ 5.5 MB |
| 其中：UPX 后二进制 | ≈ 3.8 MB |
| 其中：stdlib zip（-OO + 去调试范围 + zopfli） | ≈ 1.7 MB |

## 已内置的能力（摘要）

- 网络/解析：`socket` `ssl` `select` `selectors` `http.*` `urllib.*` `email` `html` `xml(etree/expat)` `json` `csv`
- 数据/系统：`sqlite3` `zlib` `hashlib`（含 sha3/blake2）`hmac` `secrets` `struct` `decimal` `statistics`
- 并发：`threading` `asyncio` `concurrent.futures` `subprocess` `pty`
- 工具链：`argparse` `logging` `pathlib` `tempfile` `shutil` `tarfile` `zipfile` `gzip` `inspect` `dis` 等

## 未包含（有意裁剪）

`ctypes`（需 libffi）`readline` `curses` `tkinter` `_uuid` `lzma/bz2`（tarfile 的 xz/bz2 解码不可用，gz 正常）
`gdbm/dbm` `multiprocessing` 子包 `pydoc/idlelib/lib2to3/tests`。`_hashlib` 未含（hashlib 由内置实现覆盖常用算法）。

## iSH 注意事项

- 完全静态 + LibreSSL 内嵌 CA：**无需**任何环境变量即直连 HTTPS。
- 启动 ~0.27s（含 UPX 解压）；需要行缓冲/彩显时配合 `faketty` 使用。
- 单文件可随意放置/改名（自定位，不依赖任何同目录文件）；重装 rootfs 后用 `install.sh` 一键恢复。

## 退出码

同 CPython：正常 0；未捕获异常 1；语法错误 2；以脚本返回值为准。

## 相关工具

`qjs`（JS 引擎）· `sqlite3`（独立 CLI）· `curl`（LibreSSL 静态）
