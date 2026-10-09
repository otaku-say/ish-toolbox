# python3 —— 自解压壳单文件（动态 musl CPython 3.12 / LibreSSL / sqlite3）

自编译的动态 musl CPython 3.12.15，打包为**自解压壳单文件**：
`[静态 C 壳][xz(BCJ) 压缩载荷][72B 尾部记录]`。首次运行解压到 `/tmp/.ish-py3dyn-<id>/`，
此后每次运行只做 stat + exec（**零开销**）；单文件可随意放置/改名，天然配合 `uv`（venv/pip/tool）。

**约 5.3MB（arm64）单文件**；冷启动一次性解压（iSH ≈1.4s、Alpine 沙箱 ≈0.4s），热启动 ≈0。

## 安装（单文件直装）

```sh
sh scripts/install.sh            # 落一个文件到 PATH，并给 python 别名
python3 -V                       # → Python 3.12.15
```

## 推荐用法

```sh
# 1) 快速验证（TLS / sqlite / ctypes / lzma / bz2）
python3 -c 'import ssl, sqlite3, ctypes, lzma, bz2; print(ssl.OPENSSL_VERSION, sqlite3.sqlite_version)'
python3 -c 'from datetime import datetime; from zoneinfo import ZoneInfo; print(datetime(2026,10,9,tzinfo=ZoneInfo("Asia/Shanghai")).utcoffset())'

# 2) 零配置 HTTPS（内嵌 CA；iSH 上无需任何环境变量）
python3 -c 'import urllib.request as u; print(u.urlopen("https://example.com", timeout=20).status)'

# 3) 与 uv 配合（推荐）：venv / 安装二进制轮子 / 工具
uv venv --python "$(command -v python3)" .venv
uv pip install --python .venv/bin/python requests numpy   # musllinux 轮子可用
uv tool run cowsay -t hi

# 4) 脚本与管道
python3 script.py
echo '{"a":1}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["a"])'

# 5) 并发 / 多进程（壳会自动补建 /dev/shm）
python3 -c 'import multiprocessing as mp; print(mp.Pool(2).map(abs, [-1,-2]))'

# 6) 版本 / 信息
python3 -VV
python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))'
```

## 环境变量（壳）

| 变量 | 作用 |
|---|---|
| `PY3DYN_CACHE_DIR` | 自定义解压缓存目录（默认 /tmp/.ish-py3dyn-<id>） |
| `PY3DYN_DEBUG=1` | 输出自定位/解压诊断信息 |

## 已内置（摘要）

- 网络/解析：`ssl`（LibreSSL 内嵌 CA，零配置 HTTPS）`socket` `http.*` `urllib.*` `email` `html` `xml` `json` `csv`
- 数据/系统：`sqlite3` `zlib` `bz2` `lzma` `hashlib` `hmac` `uuid` `decimal` `statistics`
- 扩展/二进制生态：`ctypes`（libffi 静态链入）——musllinux 二进制轮子可加载（numpy/psutil 实测）
- 并发：`threading` `asyncio` `multiprocessing` `concurrent.futures` `subprocess` `pty`
- 工具链/调试：`argparse` `logging` `pathlib` `unittest` `doctest` `pdb` `cProfile` `tomllib` `zoneinfo`（内嵌 tzdata）
- 完整模块白名单 125/125 导入实测通过（含 ctypes/lzma/bz2/uuid/multiprocessing/unittest）

## 未包含（有意裁剪）

`ensurepip/pip`（依赖管理请用配对的 `uv`：`uv pip`）、`tkinter` `readline` `curses` `gdbm/dbm` `nis`。
`_hashlib` 未含（hashlib 由内置实现覆盖常用算法）。

## 系统要求

- musl 系（Alpine、iSH）自带 loader，直接使用；glibc 系需 `apt install musl` 提供 `/lib/ld-musl-<arch>.so.1`。
- 壳首次运行会自动补建 `/dev/shm`（iSH 默认没有，multiprocessing 需要）。

## iSH 注意事项

- 首次运行解压约 1.4s（一次性）；之后热启动 ≈ 0ms。
- 需要行缓冲/彩显时配合 `faketty` 使用。
- 单文件自定位（/proc/self/exe → argv[0] → PATH 搜索），可随意放置。

## 退出码

同 CPython：正常 0；未捕获异常 1；语法错误 2；以脚本返回值为准。

## 相关工具

`uv`（推荐配对：venv/pip/tool）· `sqlite3` · `qjs` · `curl`
