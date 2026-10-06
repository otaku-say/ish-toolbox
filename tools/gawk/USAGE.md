# gawk（5.4.1，全静态）

> 一行定位：GNU Awk——完整 awk 实现（POSIX + GNU 扩展：`gensub`/`asort`/`FPAT`），5.3 起内置 **CSV 模式**。

## 推荐用法（可原样复制）

```sh
printf 'a b c\n' | gawk '{print $3}'            # → c
gawk -F: '{print $1}' /etc/passwd               # 按分隔符取列
gawk --csv '{print $2}' data.csv                # CSV 模式（引号/嵌逗号正确解析）
gawk 'BEGIN{printf "%.2f\n", 3.14159}'          # → 3.14
gawk '{s+=$1} END{print s}' nums.txt            # 求和
gawk 'length($0)>80' file.txt                   # 行过滤（打印超长行）
```

## 常用参数

| 参数 | 说明 |
|---|---|
| `-F <sep>` | 字段分隔符 |
| `--csv` | CSV 模式（5.3+；正确处理引号转义与嵌逗号） |
| `-v k=v` | 传入变量 |
| `-f prog.awk` | 从文件读程序 |
| `--posix` | 严格 POSIX 模式（关 GNU 扩展） |

## 退出码与错误处理

- `0` 正常；`1` 运行时错误（如 `division by zero`）；`2` 用法/程序语法错
- 过滤无匹配时**不**输出但 rc 仍为 0（awk 与 grep 的语义差异，注意）

## iSH 注意事项

- BusyBox awk 功能受限（缺 `gensub`/`asort`/`--csv` 等）：**脚本依赖 GNU 特性时必须显式 `gawk`**
- 本构建参数：`--disable-extensions`（静态不支持 dlopen 扩展）、`--disable-mpfr`（无 MPFR 任意精度）
- 版本串里的 "PMA Avon" = gawk 5.4 的持久内存分配器实现名（正常版本标记，不是问题）
- 无 iSH 专属补丁（纯上游）

## 相关工具

`jaq`（JSON）、`sd`（文本替换）、`csvquote`（CSV 与 awk 双通管道搭档）、`rg`（搜索）。
