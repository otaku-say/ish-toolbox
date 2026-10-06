# qjs —— QuickJS-NG 引擎（0.17.0，跑 JS 小脚本）

独立 JavaScript 解释器（支持顶层 await），适合一次性的算数/JSON/正则/文本处理。
**不是 Node**：没有 `require`、`process`、npm；文件系统和环境变量要用 `--std` 打开的 `os`/`std`。

## 推荐用法

```sh
# -e 直接求值
qjs -e 'console.log(1+2)'

# 顶层 await 可用
qjs -e 'const r = await Promise.resolve(42); console.log(r)'

# 执行脚本文件
qjs t.js

# 文件系统/环境变量：必须加 --std，直接访问 os./std. 对象
qjs --std -e 'console.log(os.getcwd()[0])'
qjs --std -e 'console.log(std.getenv("HOME"))'

# 注意：os 的文件系统函数返回 [结果, errno] 二元组（本机实测，取 [0]）
qjs --std -e 'console.log(os.readdir(".")[0].join(","))'
qjs --std -e 'console.log(JSON.stringify(os.stat(".")[0]))'

# 执行前先加载别的脚本（-I）
qjs -I inc.js -e 'console.log("main")'

# 资源限制 / 退出时打印内存统计
qjs --memory-limit 65536 -e 'console.log("ok")'
qjs -d -e 'var a=[1,2,3]'
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-e EXPR` | 求值表达式/语句 |
| `-m` | 按 ES 模块加载（默认自动识别） |
| `-I FILE` | 预加载脚本 |
| `--std` | 开放内置 `std`/`os`/`bjson` |
| `--memory-limit N` | 内存上限（KB） |
| `--stack-size N` | 栈上限（KB） |
| `-q` | 只初始化解释器后退出 |
| `-d` | 退出时打印内存统计 |
| `-v` | 版本号 |

## 退出码

- `0` = 正常
- `1` = 未捕获异常（语法错、运行错都是 1，实测）

## iSH 注意事项

- **`import ... from "os"` 在本机任何模式都失败**（实测 `ReferenceError: could not load module filename 'os'`）；
  内置模块只能靠 `--std`，然后用全局 `os`/`std`。
- **os 的部分函数返回 `[值, errno]` 二元组**（实测 `getcwd`/`readdir`/`stat`）：取 `[0]` 拿结果；
  `os.getpid()`、`os.platform`、`std.*` 则直接返回，两种都按实测来。
- 无 Node 生态：`require`、`process` 不存在，npm 不可用；`TextEncoder` 等 Web API 也没有（实测 undefined）。
- 全静态 aarch64 二进制，不依赖 apk 包。

## 相关工具

- `python3` —— 完整 Python 解释器（本套件自带，全静态）
- `jaq` —— 命令行 JSON 处理
- `sqlite3` —— 数据落库
