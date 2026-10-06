# lowdown —— Markdown → HTML / 终端文本 / roff（多格式转换）

Markdown 解析与渲染工具（kristapsdz 出品）：默认输出 HTML，也能直接渲染成
**终端可读文本**（`-t term`）、roff man/ms（写手册页）、LaTeX 等。

## 推荐用法

```sh
# 1) Markdown → HTML（默认）
lowdown README.md > README.html

# 2) 终端直接读（排版文本）；进管道/存档加 --term-no-ansi 得纯文本
lowdown -t term NOTES.md
lowdown -t term --term-no-ansi NOTES.md > clean.txt

# 2b) 长表格自动按词折行（宽度 --term-width；关掉用 --term-no-tablewrap）
lowdown -t term --term-width 60 report.md

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
| `--term-no-ansi` | `-t term` 输出纯文本（无 ANSI；旧名 `--term-no-colour` 弃用不生效） |
| `--term-no-style` | 同上：不带样式的纯文本 |
| `--term-no-tablewrap` | 关闭 `-t term` 的长表格按词折行 |
| `--term-width N` | `-t term` 的文档宽度（影响表格折行） |
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
- **`-t term` 默认输出 ANSI 色彩**：纯文本请用 **`--term-no-ansi`**（3.2.1 实测直出纯文本；
  旧名 `--term-no-colour` 是弃用别名、不生效）。长表格默认按词折行——`--term-width N` 设宽度，
  `--term-no-tablewrap` 关闭（均实测生效）。
- 中文按 UTF-8 透传；宽度按字符列计算（宽字符视作单列，超宽表格可能错位）。

## 相关工具

- `html2text` —— 反方向：HTML → 文本
- `strip-ansi` —— 给任何输出（如漏网 ANSI）再洗一遍的兜底
- `hxselect` —— 从 HTML 里精取片段
- `faketty` —— 需要给 `-t term` 输出上色/分页时组合
