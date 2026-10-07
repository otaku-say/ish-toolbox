# busybox（1.38.0，全静态）

> 一行定位：瑞士军刀——单文件包含 300+ Unix 命令（ls/cat/grep/sed/awk/find/tar/wget...），iSH 自带 busybox 的完整版。

## 推荐用法（可原样复制）

```sh
busybox ls -la                    # 列出目录（等价于 ls）
busybox cat file.txt              # 查看文件
busybox grep "pattern" file.txt   # 搜索文本
busybox find / -name "*.txt"      # 查找文件
busybox tar xzf archive.tar.gz    # 解压
busybox wget https://example.com  # 下载文件
busybox sh                        # 启动 shell
```

## 常用命令

| 命令 | 说明 |
|---|---|
| `ls` / `cat` / `echo` | 基础文件操作 |
| `grep` / `sed` / `awk` | 文本处理 |
| `find` / `locate` | 文件查找 |
| `tar` / `gzip` / `bzip2` | 压缩解压 |
| `wget` / `curl` | 网络下载 |
| `ps` / `top` / `kill` | 进程管理 |
| `df` / `du` / `free` | 系统监控 |
| `vi` / `nano` | 文本编辑器 |
| `sh` / `bash` | Shell |

## 退出码与错误处理

- 各命令遵循标准 Unix 退出码约定（0=成功，非 0=失败）
- 使用 `busybox <command> --help` 查看具体命令帮助

## iSH 注意事项

- 本构建为 **defconfig 默认配置**，包含 300+ 命令，体积约 2.1MB（arm64）/ 2.6MB（amd64）
- 与 iSH 自带 busybox 功能互补：iSH 自带的是精简版，本构建是完整版
- 静态链接，无外部依赖，可直接复制到任何 Linux 系统使用

## 相关工具

`tmux`（终端复用）、`bash`（完整 shell）、`gawk`（GNU awk）——命令行工具链。
