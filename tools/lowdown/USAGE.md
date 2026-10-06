# lowdown —— Markdown → HTML / 终端文本 / roff（多格式转换）

Markdown 解析与渲染工具（kristapsdz 出品）：默认输出 HTML，也能直接渲染成
**终端可读文本**（`-t term`）、roff man/ms（写手册页）、LaTeX 等。

## 推荐用法

```sh
# 1) Markdown → HTML（默认）
lowdown README.md > README.html

# 2) 终端直接读（排版好的纯文本，适合聊天/日志）
lowdown -t term NOTES.md

# 3) 完整 HTML 文档（含 <head>，可直接当网页）
lowdown -s -o page.html page.md

# 4) 生成手册页（man/ms 源码）
lowdown -t man tool.1.md > tool.1
lowdown -t ms  paper.md > paper.ms

# 5) 元数据（front-matter / -M 注入）
lowdown -s -M title="My Doc" -o out.html in.md

# 6) 版本 / 帮助
lowdown --version      # lowdown 3.2.1
lowdown -h
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-t MODE` | 输出模式：`html`（默认）/ `term` / `man` / `ms` / `latex` / `tree` / `fodt` 等 |
| `-s` | 输出"独立完整文档"（HTML 带 DOCTYPE/head；其他模式同理） |
| `-o FILE` | 输出文件 |
| `-M key=val` / `-m key=val` | 元数据（输出侧 / 输入侧） |
| `-X keyword` | 提取指定元数据字段 |
| `-L` | 列出可用元数据键 |
| `-h` | 帮助 |

## 退出码 / 错误处理

- 0 成功；非 0 失败（输入错误/不支持的模式）。
- 单文件、单进程；输入从文件参数或 stdin。

## iSH 注意事项

- 本套件为**自编译静态**（构建用 bmake——BSD make 语法，GNU make 编不了）；真机可用。
- **`-t term` 默认输出 ANSI 色彩**（标题加粗/强调；`--term-no-colour` 在 3.2.1 实测无效）：
  进管道/存档前接 `strip-ansi` 清洗即可（本套件自带），例：
  `lowdown -t term NOTES.md | strip-ansi`。
- 中文按 UTF-8 透传；宽度按字符列计算（宽字符视作单列，超宽表格可能错位）。

## 相关工具

- `html2text` —— 反方向：HTML → 文本
- `strip-ansi` —— 洗掉 `-t term` 输出的 ANSI 色彩
- `hxselect` —— 从 HTML 里精取片段
- `faketty` —— 需要给 `-t term` 输出上色/分页时组合
