# micropython —— 嵌入式 Python 解释器（v1.29.0）

单文件、启动快的 Python 实现，语法接近 Python 3.4+，适合一次性小脚本、算法验证、JSON/文本处理。
**不是 CPython**：标准库是子集，没有第三方包和 pip；本机编译时还关掉了 ssl/ffi/btree。

## 推荐用法

```sh
# -c 单行
micropython -c 'print(1+2)'

# 跑脚本文件
micropython t.py

# 标准库实测可用：json / math / os / sys / re / io / gc / time
micropython -c 'import json, math; print(json.dumps({"pi": round(math.pi,3)}))'

# sys.argv：-c 也占第 0 位
micropython -c 'import sys; print(sys.argv)' a b

# 调大 GC 堆（大对象多时用）
micropython -X heapsize=64K -c 'print("heap ok")'

# REPL：管道喂脚本也能执行（实测）
printf 'print(7*7)\n' | micropython -i
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-c CMD` | 执行字符串 |
| `-m MOD` | 以模块方式运行（可用模块很少，见 `help("modules")`） |
| `-X heapsize=…` | 设置 GC 堆大小（默认约 2MB） |
| `-i` | 执行后进 REPL（管道输入可执行完退出） |
| `--version` / `-h` | 版本 / 帮助 |

## 退出码

- `0` = 正常
- `1` = 未捕获异常（打印 Traceback，实测 ZeroDivisionError → 1）

## iSH 注意事项

- **没有 ssl**：`import ssl` → `ImportError: no module named 'tls'`（实测），HTTPS 别想。
  **没有 ffi、没有 btree**（实测 ImportError）；`sqlite3` 模块也没有。
- `help("modules")` 列出的名字不一定能 import：`ssl` 就在列表里，但一 import 就挂（实测）。
- 不是 CPython 惯例：`-m json.tool` 这类不存在（实测 `ImportError: no module named 'json.tool'`），别按 CPython 模块路径猜。
- 全静态 aarch64 二进制，不依赖 apk 包。

## 相关工具

- `qjs` —— JS 版小脚本引擎
- `sqlite3` —— 外部 CLI 操作数据库（Python 里没有 sqlite3 模块）
- `jaq` —— 命令行处理 JSON 更快
