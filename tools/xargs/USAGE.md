# xargs —— GNU findutils 4.11.0（全静态单文件；配套同装 find）

> 一行定位：GNU 版 xargs——`-P` 真并行、`-I` 替换、`--delimiter`、`-o` 等完整选项；busybox 的 xargs 选项少。

## 推荐用法（可原样复制）

```sh
X=/path/to/tools/xargs/arm64/xargs  # iSH/arm64；amd64 换 amd64 目录

seq 1 8 | "$X" -P4 -n2 echo          # 4 路并行、每批 2 个参数
find . -name '*.log' -print0 | "$X" -0 gzip      # NUL 安全批量（推荐）
printf 'a\nb\n' | "$X" -I{} echo "item: {}"      # 逐项替换
"$X" --show-limits < /dev/null       # 查看系统参数长度上限（GNU）
"$X" -a out.txt echo                 # 从文件读条目
seq 5 | "$X" -r echo                 # 空输入不执行（GNU 默认即 -r）
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-0` | NUL 分隔输入（配 `find -print0`） |
| `-n N` | 每批 N 个参数 |
| `-P N` | 并行 N 个进程（-P0 尽可能多） |
| `-I {}` | 逐条替换（隐含 -L1） |
| `-d C` | 自定义分隔符 |
| `-a FILE` | 从文件读入 |
| `-t` | 执行前打印命令 |
| `--show-limits` | 显示系统限制 |

## 退出码

- `0` 成功；`123` 子命令以 1-125 退出；`124` 子命令以 255 退出；`125` 被信号杀；`126/127` 命令无法执行

## iSH 注意事项

- 全静态 aarch64/amd64 单文件；体积约 0.05 / 0.06（UPX 后）
- 并行度建议：iSH 上 `-P2`~`-P4` 足够；`-P0` 在低配机会过载
- 与 busybox xargs 差异：`-P`、`--delimiter`、`--show-limits`、`-o` 等为 GNU 完整语义

## 相关工具

- `find` —— 同包配套（-print0 组合）
- `parallel`（未收录）—— 更复杂的并行编排可用 `xargs -P` 代替
