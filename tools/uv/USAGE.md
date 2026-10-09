# uv —— 官方 musl 静态 uv 的自解压壳单文件

打包官方 [uv](https://github.com/astral-sh/uv)（极速 Python 包管理器，musl 静态版 0.12.24）为
**自解压壳单文件**：`[静态 C 壳][xz(BCJ) 压缩载荷][72B 尾部记录]`；首次运行解压到
`/tmp/.ish-py3dyn-<id>/`，之后每次运行零开销。

与工具箱 `python3`（动态 musl）配对使用：`uv venv` / `uv pip` / `uv tool run` 全功能可用。
注意 uv 需要**动态链接**的 Python——全静态 python3 会被 uv 拒绝（`Could not detect a glibc or a musl libc`），
工具箱 python3 即动态版本，二者天然配对。

## 推荐用法

```sh
uv --version                              # uv 0.12.24
uv venv --python /path/to/python3 .venv   # 用工具箱 python3 建环境
uv pip install --python .venv/bin/python requests numpy
uv pip list --python .venv/bin/python
uv tool run cowsay -t hi                  # 等价 uvx（本工具箱不单独提供 uvx 入口）
```

## 说明

- 单文件、自定位、可改名；缓存策略同 python3（首次解压一次性，之后零开销）。
- `uvx`：不单独提供——请用 `uv tool run <工具>` 等价替代（官方 uvx 需与其同目录的 uv 二进制配合）。
- 载荷来自官方 Release 资产，构建时用官方 sha256 逐字节校验（见仓库 `scripts/build/uv.sh`）。
- 升级：仓库 GitHub Actions 手动触发 `build-uv` 并填 `uv_version=latest`。

## 系统要求 / 环境变量 / 退出码

- musl 系（Alpine、iSH）直接可用；glibc 系需 `apt install musl`（与 python3 相同）。
- `PY3DYN_CACHE_DIR`、`PY3DYN_DEBUG=1`：与 python3 共用的壳环境变量。
- 退出码同 uv 原版。

## 相关工具

`python3`（配对）· `curl` · `sqlite3`
