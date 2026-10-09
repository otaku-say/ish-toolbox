# sed —— GNU sed 4.10（全静态）

> 一行定位：GNU 流编辑器——`-i` 原位编辑、`\t`/`\xNN` 等转义、区间/分组等 GNU 扩展；busybox sed 与此差距明显。

## 推荐用法（可原样复制）

```sh
S=/path/to/tools/sed/arm64/sed      # iSH/arm64；amd64 换 amd64 目录

"$S" -i 's/old/new/' file.txt        # 原位替换（GNU -i 裸用即可）
"$S" -i.bak 's/a/b/g' file.txt       # 原位替换并留 .bak 备份
printf 'a\tb\n' | "$S" 's/\t/ /'     # \t 等转义（busybox 部分版本不支持）
seq 1 5 | "$S" -n '2,4p'             # 打印 2~4 行
"$S" -n '/^ERROR/{=;p}' log.txt      # 打印行号+内容
"$S" -E 's/(foo)+/X/g' file          # ERE 分组
"$S" '/BEGIN/,/END/d' file.txt       # 删除区间
"$S" -n '$p' file.txt                # 只打最后一行
"$S" 's/./\U&/g' <<< hmm             # 转大写（GNU 扩展）
```

## 常用参数

| 参数/语法 | 作用 |
|---|---|
| `-i[SUFFIX]` | 原位编辑（可带备份后缀） |
| `-n` | 默认不输出（配合 `p`） |
| `-E` / `-r` | ERE 正则 |
| `-e SCRIPT` | 多个脚本段 |
| `-s` | 按文件分段处理 |
| `-z` | NUL 行分隔 |
| `s///g` `s///I` | 全局 / 忽略大小写 |
| `\t` `\xNN` `\U` `\L` | 转义/大小写（GNU 扩展） |

## 退出码

- `0` 正常处理；`1` 命令语法错误等；`2` 输入文件错误；`q N` / `Q N` 可自定义退出码（GNU 扩展）

## iSH 注意事项

- 全静态 aarch64/amd64 单文件；体积约 0.10 / 0.09 MB（arm64 / amd64，UPX 后）
- `-i` 在 iSH 文件系统上正常工作（重命名式实现）
- 超大文件建议用流式管道（`-n` + `p`）而非 `-i`

## 相关工具

- `grep` / `find` / `xargs` / `diff` —— 文本与文件 FOUR 件套
- `gawk` —— 更复杂文本加工时的选择
