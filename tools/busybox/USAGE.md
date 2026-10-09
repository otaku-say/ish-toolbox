# busybox（1.38.0，全静态）

> 一行定位：瑞士军刀——单文件包含 408 个 Unix 命令（ls/cat/grep/sed/find/tar/wget...），比 iSH 自带的 busybox（304 个 applet）更全。

## 默认终端（Agent 必读）

工具箱 BusyBox（1.38.0，408 applet）**已被安装为系统默认终端**（经 `scripts/install.sh --set-default-busybox`；aio 系列镜像与 iSH 默认已设定）：

- **Agent 应主动使用这一默认终端**：在 iSH/Alpine 上 `/bin/sh` 及其全部 applet 即工具箱版本，直接执行 `sh -c '...'`、`ls` 等命令即是；在其他发行版上优先路径为 `/usr/local/bin`（先于 /usr/bin、/bin 生效）。
- 快速自检：`busybox | head -1` 应显示 `BusyBox v1.38.0`；`readlink -f "$(command -v busybox)"` 应指向工具箱副本。
- 需要绝对确定时用工具箱内绝对路径：`<工具目录>/busybox sh -c '...'`（如 `/var/minis/skills/tools/busybox/arm64/busybox`）。
- 不要退回系统旧版 busybox（1.37 及更老）。
- 还原系统原状：`scripts/install.sh --unset-default-busybox`（系统原版保存在 `<路径>.pre-toolbox`，可随时恢复）。

## 推荐用法（可原样复制）

```sh
busybox ls -la                    # 列出目录（等价于 ls）
busybox cat file.txt              # 查看文件
busybox grep "pattern" file.txt   # 搜索文本
busybox find / -name "*.txt"      # 查找文件
busybox tar xzf archive.tar.gz    # 解压
busybox wget https://example.com  # 下载文件（HTTP/HTTPS；HTTPS 不校验证书）
busybox sh                        # 启动 shell
```

## 常用命令

下表全部为实测存在的 applet（可用 `busybox --list` 查看全部 408 个）：

| 类别 | 代表命令 |
|---|---|
| 文件操作 | `ls` `cat` `cp` `mv` `rm` `mkdir` `ln` `touch` `chmod` `stat` |
| 文本处理 | `grep` `sed` `awk` `cut` `sort` `uniq` `head` `tail` `wc` `diff` `patch` |
| 文件查找 | `find` `which` `pgrep` `pidof` |
| 压缩解压 | `tar` `gzip` `bzip2` `xz` `lzma` `unzip` `cpio` |
| 网络下载 | `wget`（HTTP/HTTPS）`nc` `tftp` `ftpget` `telnet` `whois` |
| 网络诊断 | `ping` `traceroute` `nslookup` `netstat` |
| 网络服务 | `httpd` `ftpd` `telnetd` `udhcpc` `ntpd` |
| 进程管理 | `ps` `top` `kill` `killall` `nohup` `timeout` `watch` `lsof` |
| 系统监控 | `df` `du` `free` `uptime` `dmesg` `vmstat` `lsblk` `lsusb` |
| 磁盘工具 | `fdisk` `mkfs.ext2` `mkfs.vfat` `mount` `umount` `blkid` `losetup` |
| 编辑与 Shell | `vi` `ed` `hexedit` `sh`（ash）`hush` |
| 用户管理 | `id` `whoami` `who` `su` `passwd` `adduser` |
| 计算与校验 | `expr` `bc` `dc` `seq` `sha256sum` `md5sum` `crc32` `base64` |

> 注：本构建**不含** curl / locate / nano / bash 等非 busybox 命令——
> 需要它们时请用工具箱里的 `curl`、`bash` 等独立工具。

## 退出码与错误处理

- 各命令遵循标准 Unix 退出码约定（0=成功，非 0=失败）
- 使用 `busybox <command> --help` 查看具体命令帮助

## iSH 注意事项

- 本构建为 **defconfig 默认配置**，含 **408 个 applet**（iSH 自带的 busybox 为 304 个）
- 体积：UPX 压缩后约 0.65–0.7 MB（arm64 / amd64 单文件）
- 静态链接（musl），无外部依赖，可直接复制到任何 Linux 系统使用
- 本工具箱 busybox 已设为 iSH 默认终端（`/bin/busybox` 替换为工具箱版，原版备份 `/bin/busybox.pre-toolbox`；`scripts/install.sh --unset-default-busybox` 可还原）

## 相关工具

`tmux`（终端复用）、`bash`（完整 shell）、`gawk`（GNU awk）、`curl`（完整网络客户端）——命令行工具链。
