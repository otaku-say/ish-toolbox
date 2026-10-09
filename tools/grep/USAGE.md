# grep —— GNU grep 3.12（全静态；含 PCRE2 的 -P 支持）

> 一行定位：GNU 版文本搜索——`-P` Perl 正则（`\d`、`\w`、前瞻等）、`-r` 递归、完整编码处理；**busybox 的 grep 没有 `-P`**。

## 推荐用法（可原样复制）

```sh
G=/path/to/tools/grep/arm64/grep     # iSH/arm64；amd64 换 amd64 目录

"$G" -rn "pattern" dir/               # 递归搜索 + 行号
"$G" -P '\d{3}-\d{4}' file.txt        # Perl 正则（PCRE2 已静态编入）
"$G" -oP '[\w.+-]+@[\w.-]+' mail.txt  # 只输出匹配到的那一段
"$G" -i --include='*.md' -r TODO .    # 忽略大小写、只搜 *.md
"$G" -c "error" log.txt               # 计数
"$G" -A3 -B2 "panic" log.txt          # 带上下文（后 3 / 前 2 行）
"$G" -E "^(foo|bar)+$" file           # 扩展正则（ERE）
"$G" -l "pattern" -r dir              # 只列命中文件名
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-P` | Perl 正则（PCRE2；`\d` `\s` 前瞻后顾等） |
| `-E` / `-F` | 扩展正则 / 固定字符串 |
| `-r` / `-R` | 递归目录（-R 跟随符号链接） |
| `-i` | 忽略大小写 |
| `-o` | 只输出匹配片段 |
| `-n` | 行号 |
| `-c` | 计数 | 
| `-l` / `-L` | 列文件名 / 列不出现的文件 |
| `-A n` / `-B n` / `-C n` | 后 / 前 / 前后上下文 |
| `--include` / `--exclude` | 按文件名过滤 |
| `-z` | NUL 分隔（配合 `xargs -0`） |

## 退出码

- `0` 有匹配；`1` 无匹配；`2` 出错（脚本里注意区分 1 与 2）

## iSH 注意事项

- 全静态 aarch64/amd64 单文件；体积约 0.20 / 0.20（UPX 后）
- `-P` 为真 PCRE2（10.49 静态链入）——不是 busybox 的"假 -P"
- 大目录递归搜索建议用 `rg`（更快、默认忽略 .gitignore）；需要 GNU 语义/PCRE/特殊边界时用本工具

## 相关工具

- `rg` —— 更快的搜索（Rust；默认 gitignore 感知）
- `sed` / `find` / `xargs` —— 文本与文件三板斧的 GNU 版
- `jaq` —— 结构化数据加工
