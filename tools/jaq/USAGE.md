# jaq —— jq 的 Rust 实现（v3.1.1）

JSON 过滤/转换语言，`jaq '过滤器' [文件]`，语法与 jq 基本一致；本机可能没有 jq，直接用 jaq。
v3 特有：模块系统、大整数不丢精度、YAML 等格式；jq 的 `--stream`、`-a` 在**本版未实现**。

## 推荐用法

```sh
# 过滤字段（stdin 或文件）
echo '{"name":"alice"}' | jaq '.name'
jaq '.name' d.json

# -r 去引号；-c 紧凑输出
jaq -r '.name' d.json
jaq -c '.nums' d.json

# -n 不读输入直接算
jaq -n '1+2'

# --arg / --argjson 传变量
jaq -nr --arg x hello '"v="+$x'
jaq -n --argjson v '[1,2]' '$v[1]'

# -e 用最后输出值当退出码（false/null → 1）
jaq -e -n 'true'

# 大整数不丢精度（jq 会截断）
jaq '.big' d.json

# 排序键 / 输出间不加换行
jaq -S -n -c '{b:1,a:2}'
jaq -j -n '"a","b"'

# 就地改写文件
jaq -i -c '.k+1' m.json

# YAML 输入（实测可用；jq 不支持）
jaq --from yaml -c '.a' x.yaml

# v3 模块系统
jaq -n -L . 'import "lib" as lib; 3 | lib::double'
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-n` | 不读输入（拿 null 当输入） |
| `-r` | 字符串输出不带引号 |
| `-c` | 紧凑 JSON |
| `-s` | 把输入值序列收成一个数组 |
| `-R` | 按原始文本行读输入 |
| `-e` | 用最后输出值决定退出码 |
| `-i` | 就地改写输入文件 |
| `-S` | 对象键排序 |
| `-j` | 输出之间不加换行 |
| `-L DIR` | 模块搜索目录 |
| `--arg A V` | 传字符串变量 `$A` |
| `--argjson A V` | 传 JSON 变量 `$A` |
| `--args` | 位置参数收进 `$ARGS.positional` |
| `--from FMT` | 输入格式（如 yaml） |
| `--indent N` | 缩进空格数 |

## 退出码

- `0` = 正常（`-e` 时看最后输出：false/null → 1、无输出 → 4）
- `2` = 选项错；`3` = 语法错；`5` = 运行错（如 `error()`）

## iSH 注意事项

- **未实现**（实测报 unknown flag）：`--stream`、`-a`；照 jq 文档抄这两个会直接失败。
- `-s` 收的是 JSON 值序列；纯文本要配合 `-R`（如 `-R -s`），否则报 parse error（实测）。
- 大整数真的保留：`123456789012345678901234567890` 原样输出（实测）。
- YAML 输入实测可用（`--from yaml`）；`-i` 就地改写实测可用。
- 全静态 aarch64 二进制，不依赖 apk 包。

## 相关工具

- `qjs` —— JSON.parse/stringify 的小活
- `micropython` —— 复杂逻辑用 Python
- `rg` —— 纯文本搜索
