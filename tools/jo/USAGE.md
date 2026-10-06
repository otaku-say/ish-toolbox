# jo —— 从命令行参数生成 JSON

在 shell 里拼 JSON 的最省事工具：`key=value` 直接变 `{"key":"value"}`，
支持嵌套（`key=$(jo ...)`）、数组、类型自动识别（数字/布尔/null）。

## 推荐用法

```sh
# 1) 基本：键值 → JSON（值自动识别数字）
jo name=alice age=30                       # {"name":"alice","age":30}

# 2) 美化输出 + 嵌套
jo -p user=$(jo name=alice) tags=$(jo -a a b c)

# 3) 数组
jo -a 1 2 3                                # [1,2,3]
jo -a $(jo -a 1 2) $(jo -a 3 4)            # 嵌套数组

# 4) 类型控制
jo x=true                                  # {"x":true}
jo -B x=true                               # {"x":"true"}（关闭布尔/null 识别）
jo -n x=3.14                               # {"x":3.14}
jo x=                                       # {"x":null}（空值）

# 5) 对象路径（-d 分隔符）：一次拼嵌套
jo -d . user.name=alice user.age=30        # {"user":{"name":"alice","age":30}}

# 6) 管道给 curl / API
curl -sS -X POST -H 'Content-Type: application/json' \
     -d "$(jo title=demo done=true)" https://example.com/api

# 7) 版本 / 帮助
jo -v                                      # jo 1.9
jo -h
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-a` | 数组模式（按词生成数组） |
| `-p` | 美化输出（缩进） |
| `-B` | 关闭 `true/false/null` 自动识别（一律当字符串） |
| `-n` | 数值化（`x=007` → `7`） |
| `-e` | 空值处理（`x=` → `{"x":null}`） |
| `-D` | 对象键去重 |
| `-d SEP` | 键按 SEP 拆成对象路径（如 `-d . a.b=1`） |
| `-o FILE` | 输出到文件 |
| `-f FILE` | 从文件读 word（每行一个） |
| `-v` / `-h` | 版本 / 帮助 |

## 退出码 / 错误处理

- 0 成功；非 0 失败（参数格式错误等），错误信息在 stderr。
- 生成的是**无空格的紧凑 JSON**（除 `-p`）；管道场景安全。

## iSH 注意事项

- 纯静态单文件，无运行时依赖；真机可用（本套件自编译）。
- 值里有空格/特殊字符用引号包住：`jo msg="hello world"`；`key@value` 形式可避免 `=` 冲突。
- 与其配套的查询/解析用 `gojq` / `jaq`（本套件内含）。

## 相关工具

- `gojq` / `jaq` —— JSON 查询/变换（jo 管生成）
- `xxhsum` —— 给生成的结果做校验
- `curl` —— 把 jo 的输出 POST 出去
