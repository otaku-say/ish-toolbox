# diff —— GNU diffutils 3.12（全静态）

> 一行定位：GNU diff——unified 格式、目录递归对比、彩色输出；配 `patch` 组成标准打补丁流。

## 推荐用法（可原样复制）

```sh
D=/path/to/tools/diff/arm64/diff    # iSH/arm64；amd64 换 amd64 目录

"$D" -u old.txt new.txt              # unified 格式（patch 用；rc=1 表示有差异）
"$D" -u old.txt new.txt > fix.patch  # 生成补丁（配合工具箱 patch 使用）
"$D" -r dir1/ dir2/                  # 目录递归对比
"$D" -q a.txt b.txt                  # 只报"是否不同"
"$D" -y a.txt b.txt                  # 并排显示
"$D" -w a.txt b.txt                  # 忽略空白差异
"$D" --color=auto -u a.txt b.txt     # 彩色（终端下）
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-u` / `-c` | unified / context 格式 |
| `-r` | 递归目录 |
| `-q` | 简洁模式（只报不同） |
| `-y` | 并排 |
| `-w` / `-b` | 忽略空白 / 忽略空白量变化 |
| `-i` | 忽略大小写 |
| `-N` | 目录对比时把缺失文件视为空（生成新文件补丁） |
| `--color=auto` | 彩色输出 |

## 退出码

- `0` 相同；`1` 有差异（≠错误）；`2` 出错——脚本里判断"有没有差异"要按 0/1/2 三分

## iSH 注意事项

- 全静态 aarch64/amd64 单文件；体积约 0.11 / 0.11 MB（arm64 / amd64，UPX 后）
- 本工具箱只收录 `diff`；`cmp` 由 busybox 提供，`diff3`/`sdiff` 未收录
- 「diff <(cmd1) <(cmd2)」进程替换在工具箱 bash 下可用

## 相关工具

- `patch` —— 应用 diff 生成的补丁（工具箱已含）
- `grep` / `sed` —— 文本处理配套
