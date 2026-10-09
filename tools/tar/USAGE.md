# tar —— GNU tar 1.35（全静态单文件）

> 一行定位：GNU 版 tar——`-a` 按后缀自动选压缩、`--exclude-*` 通配、增量备份（`--listed-incremental`）、`-J/-z/-j` 调用外部压缩器。

## 推荐用法（可原样复制）

```sh
T=/path/to/tools/tar/arm64/tar      # iSH/arm64；amd64 换 amd64 目录

"$T" cf backup.tar dir/              # 只打包
"$T" czf backup.tgz dir/             # gzip 一体（gz）
"$T" cJf backup.txz dir/             # xz 一体（需 PATH 中有可压缩的 xz）
"$T" caf backup.tar.zst dir/         # -a：按扩展名自动选压缩
"$T" tf backup.tar                   # 查看内容
"$T" xf backup.tgz                   # 解包（自动识别 gzip）
"$T" xf backup.tar -C /tmp/out       # 解到指定目录
"$T" cf b.tar --exclude='*.tmp' --exclude-vcs dir/   # 排除规则
"$T" --version | head -n1            # → tar (GNU tar) 1.35
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `c` / `x` / `t` | 创建 / 解包 / 列表 |
| `f FILE` | 指定归档文件 |
| `z` / `j` / `J` | gzip / bzip2 / xz |
| `a` | 按后缀自动压缩 |
| `C DIR` | 切换目录 |
| `--exclude[-vcs]` | 排除模式 / 排除版本控制文件 |
| `-v` | 详细输出 |
| `-p` / `--same-owner` | 保留权限（解包） |
| `--listed-incremental` | 增量备份（GNU 特性） |

## 退出码

- `0` 成功；`2` 通常表示「有错误但继续」类警告汇总（脚本里可用 `--warning=none` 收紧）

## iSH 注意事项

- 全静态 aarch64/amd64 单文件；体积约 0.34 / 0.36（UPX 后）
- `-z`（gzip）由 busybox 提供即可；**`-J`（xz）压缩需要能压缩的 xz**——busybox 的 xz 只能解压，请用工具箱 `xz`（建软链 `xz` 进 PATH 即可）
- GNU 特性对比 busybox tar：`-a`、`--exclude-*`、`--listed-incremental`、`--transform` 等完整可用

## 相关工具

- `xz` / `zip` / `zstd` —— 其它压缩格式
- `coreutils` —— 打好的包可用 `split`/`sha256sum` 等处理
