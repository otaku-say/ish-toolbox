# tree —— 目录树显示（v2.3.2）

把目录结构画成树，适合快速看布局。大目录先 `-L` 限层避免刷屏；要程序可读用 `-J`。

## 推荐用法

```sh
# 基本 / 限两层
tree proj
tree -L 2 proj

# 只列目录 / 含隐藏文件
tree -d proj
tree -a proj

# 只显示匹配 / 排除匹配（-P 针对文件，目录仍会显示）
tree -P '*.py' proj
tree -I '*.log' proj

# 大小（-h 人类可读）、类型标记、全路径
tree -s -h proj
tree -F proj
tree -f proj

# 去缩进线 / 去末尾统计行
tree -i proj
tree --noreport proj

# JSON 输出 / 写入文件
tree -J proj
tree -o out.txt proj
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-L N` | 只下降 N 层 |
| `-a` | 显示隐藏文件 |
| `-d` | 只显示目录 |
| `-P PAT` | 只显示匹配的文件 |
| `-I PAT` | 排除匹配的文件 |
| `-f` | 每行打印完整路径 |
| `-F` | 后缀标记（/、* 等） |
| `-s` / `-h` | 文件大小（字节 / 人类可读） |
| `-i` | 不画缩进线 |
| `-o FILE` | 输出到文件 |
| `-J` | JSON 输出 |
| `--noreport` | 不打印末尾统计 |

## 退出码

- `0` = 正常
- `2` = 目录打不开（实测 `/nonexistent_xyz` → `[error opening dir]` + rc=2）

## iSH 注意事项

- 对 `/`、`$HOME` 这类目录先 `-L 2`，不然输出可能巨大；也可以再接 `head` 截断。
- 管道/重定向下输出无颜色转义，可安全 diff、存储（实测输出无 ANSI）。
- 全静态 aarch64 二进制，无外部依赖。

## 相关工具

- `fd` —— 定位具体文件
- `rg` —— 在树里搜内容
- `busybox find` —— 更灵活的按条件查找
