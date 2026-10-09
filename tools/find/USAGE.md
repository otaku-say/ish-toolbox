# find —— GNU findutils 4.11.0（全静态单文件；配套同装 xargs）

> 一行定位：GNU 版 find——`-printf`、`-regex`、`-size`、`-newer`、完整表达式等高级特性；**busybox 的 find 缺其中大部分**。

## 推荐用法（可原样复制）

```sh
F=/path/to/tools/find/arm64/find     # iSH/arm64；amd64 换 amd64 目录

"$F" . -name '*.log'                  # 基本查找
"$F" . -type f -size +100M            # 大于 100MB 的文件
"$F" . -mtime -1 -ls                  # 最近 24 小时修改 + 详情
"$F" . -name '*.tmp' -delete          # 直接删除（谨慎使用）
"$F" . -printf '%s %p\n' | sort -n | tail   # -printf 定制输出（GNU）
"$F" . -regex '.*\.\(jpg\|png\)'      # 正则匹配路径（GNU）
"$F" . -name '*.c' -print0 | xargs -0 wc -l # 与同装 xargs 配合（NUL 安全）
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-name` / `-iname` / `-regex` | 名称（区分/不区分大小写）/ 完整路径正则 |
| `-type f/d/l` | 类型过滤 |
| `-size +10M` / `-empty` | 大小 / 空文件 |
| `-mtime -7` / `-newer file` | 时间条件 |
| `-maxdepth N` / `-mindepth N` | 深度限制 |
| `-printf FORMAT` | 定制输出（GNU 扩展） |
| `-exec CMD {} +` | 批量执行（+ 为高效批处理） |
| `-print0` | NUL 终止（配 `xargs -0`） |
| `-delete` | 直接删除命中项 |

## 退出码

- `0` 全部遍历成功；`1` 有部分错误（如权限拒绝）

## iSH 注意事项

- 全静态 aarch64/amd64 单文件；体积约 0.15 / 0.15（UPX 后）
- 与 busybox find 的差异：`-printf`/`-regex`/`-newerXY`/`-exec +` 等 GNU 用法完整可用
- `locate`/`updatedb` 未收录（依赖数据库与定时任务，不适合单文件形态）
- 结果排序/统计请管道给 `sort`/`wc`（工具箱 coreutils 或 busybox）

## 相关工具

- `xargs` —— 同包配套（并行、NUL 安全）
- `rg` / `fd` —— 现代替代（语法更简、速度更快；无需 GNU 语义时优先）
- `coreutils` 的 `sort`/`wc` —— 后处理
