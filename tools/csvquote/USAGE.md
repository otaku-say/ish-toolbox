# csvquote —— 让"带逗号/换行的 CSV"安全通过 awk/cut 等行工具

CSV 里被引号包住的字段可能含逗号甚至换行，直接喂 awk/cut/sed 会把一行拆错。
csvquote 先把这些"危险字符"换成不可打印占位符（全程流式、不改变数据），
处理完再用 `-u` 还原。经典双通管道：

```sh
csvquote < in.csv | awk -F, '{print $2}' | csvquote -u > out.csv
```

## 推荐用法

```sh
# 1) 取第 2 列（字段里含逗号也正确）
csvquote < report.csv | cut -d, -f2 | csvquote -u

# 2) awk 统计后还原
csvquote < data.csv | awk -F, 'NR>1{s+=$3}END{print s}' | csvquote -u

# 3) 看"危险行"在哪儿（不还原，字面量变成可见占位）
csvquote < data.csv | grep -n $'\x1f' | head
#   占位符为不可打印字符：逗号→\x1f，换行→\x1e，引号→\x1d

# 4) 自定义分隔：TSV（-t）或指定字符（-d）
csvquote -t < data.tsv | sort | csvquote -u -t

# 5) 版本 / 帮助
csvquote -h
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-u` | **还原模式**：把占位符换回原字符（管道尾端用） |
| `-d C` | 字段分隔符（默认 `,`） |
| `-t` | 等价于 `-d '\t'`（TSV） |
| `-q C` | 引号字符（默认 `"`） |
| `-r C` | 记录分隔符（默认 `\n`） |

## 退出码 / 错误处理

- 0 成功；非 0 失败（打不开文件等）。
- 纯流式：不解析整表、内存 O(1)，超大 CSV 也稳。

## iSH 注意事项

- 本套件为**自编译静态**；真机可用。
- **两道 csvquote 必须成对**：前端编码 + 尾端 `-u`；只做前端会把占位符写进结果。
- 占位符是不可打印控制字符（0x1d-0x1f）—— 数据里本身含这几个码位时会冲突（罕见）。

## 相关工具

- `awk` / `cut` / `sort` —— 被保护的"行工具"们
- `sed` / `sd` —— 更复杂的文本变换
- `xxhsum` —— 转换前后做校验
