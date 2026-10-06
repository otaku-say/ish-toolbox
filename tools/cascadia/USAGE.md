# cascadia —— 用 CSS 选择器从 HTML 提取数据（v1.5.0）

按 CSS 选择器从 HTML 抓元素（输出 HTML 源码）、文本或属性，给爬虫/页面解析调试用。
关键：`-i`、`-o`、`-c` **三个都要出现**；`-i`/`-o` 后可选跟文件名（不跟 = stdin/stdout），`-c` 后跟选择器。
这是「开关 + 可选值」语法，**不是** `-i FILE`；写 `-i -` / `-o -` 会失败。

## 推荐用法

```sh
# stdin → stdout（-i、-o 后面都不跟文件名）
cat page.html | cascadia -i -o -c 'a'

# 从文件读、写文件
cascadia -i page.html -o out.html -c 'a'

# 文本模式：-t 去首尾空白；-R 保留原始空白
cascadia -i page.html -o -c 'span' -t
cascadia -i page.html -o -c '.pad' -t -R -q

# 多个选择器（多次 -c 或用逗号组）——结果直接拼接
cascadia -i page.html -o -c 'span' -c 'a' -q

# 块模式（-p）：每个匹配元素一行，TSV；第 1 行是表头，第 2 行起才是值
cascadia -i page.html -o -c '.item' -p 'url=GOQR:a.attr(href)' -p 'num=span' -q

# 换分隔符（注意行尾会多一个分隔符/空字段）
cascadia -i page.html -o -c '.item' -p 'url=GOQR:a.attr(href)' -p 'num=span' -d , -q

# -q 压掉 stderr 的 "N elements for ..."；-w 把结果包成完整 HTML
cascadia -i page.html -o -c 'span' -w -q
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-i` | 输入文件（后随可选）；不跟 = stdin |
| `-o` | 输出文件（后随可选）；不跟 = stdout |
| `-c CSS` | 选择器，可多次 |
| `-t` | 文本输出（去首尾空白） |
| `-R` | 保留原始空白 |
| `-p PIECE` | 块模式；格式 `名=风格:选择器` |
| `-d S` | 块输出分隔符（默认 TAB） |
| `-q` | 静默提示信息 |
| `-w` | 结果包成 HTML 文档 |

`-p` 风格实测：`ATTR:名`（取块元素属性）、`GOQR:sel.attr(名)`（取块内元素属性）、不给风格 = 取文本。
其余风格（如 RAW）见 `--help`，未实测。

## 退出码

- `0` = 跑完（**输入文件不存在也是 0**，只在 stderr 写 `ERR! open ...`）
- `1` = CSS 选择器语法错误（实测 `-c 'a['` → rc=1）

## iSH 注意事项

- **别写 `-i -` / `-o -`**：单破折号不表示标准流。实测 `-o -`（末尾）→ stderr `ERR! unexpected single dash`、无数据；
  `-i - -c ...` 变体 → 直接打印 usage、rc=0。标准流请省略文件名（`-i -o` 后直接接下一个选项）。
- 少给任一必需选项 → 打印 usage 到 stdout 且 rc=0，别把 usage 当数据；脚本判失败看 stderr 的 `ERR!`。
- `N elements for 'x':` 提示走 **stderr**，用 `-q` 压掉；数据只在 stdout/输出文件里。
- 块模式行尾多一个分隔符（TSV 时行尾是 `\t`），解析时忽略最后一个空字段。
- 全静态 aarch64 二进制，不依赖 apk 包。

## 相关工具

- `curl` —— 下载页面后喂给 cascadia
- `jaq` —— 输出 JSON 后的加工
- `rg` —— 纯文本搜索场景
