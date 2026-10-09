# coreutils —— GNU Coreutils 9.12（官方多路复用单文件）

> 一行定位：GNU 官方核心工具集，**一个文件装下 100+ 个命令**（ls / cp / mv / rm / sort / head / tail / date / stat / cut / seq / sha256sum ...）；两种分发方式：`--coreutils-prog=名字` 或软链（按 argv[0] 分发）。

## 推荐用法（可原样复制）

```sh
# 本工具只有一个文件 coreutils，其余命令由它分发
C=/path/to/tools/coreutils/arm64/coreutils    # iSH/arm64；amd64 换 amd64 目录

# 方式一：单条调用（随取随用，不建软链）
"$C" --coreutils-prog=sort -V file.txt
"$C" --coreutils-prog=ls -la
"$C" --coreutils-prog=date -d "yesterday" +%F

# 方式二：软链分发（推荐——得到完全标准的 GNU 命令行为）
D=$HOME/gnu-bin; mkdir -p "$D"
for p in "[" b2sum base32 base64 basename basenc cat chgrp chmod chown chroot cksum comm cp csplit cut date dd df dir dircolors dirname du echo env expand expr factor false fmt fold ginstall groups head hostid id join link ln logname ls md5sum mkdir mkfifo mknod mktemp mv nice nl nohup nproc numfmt od paste pathchk pinky pr printenv printf ptx pwd readlink realpath rm rmdir seq sha1sum sha224sum sha256sum sha384sum sha512sum shred shuf sleep sort split stat stdbuf stty sum sync tac tail tee test timeout touch tr true truncate tsort tty uname unexpand uniq unlink users vdir wc who whoami yes; do ln -sf "$C" "$D/$p"; done
ln -sf "$C" "$D/install"      # install 用软链名（内部叫 ginstall）
export PATH="$D:$PATH"        # 或把该行写进 shell 配置
sort -V file.txt              # 此后按命令名直接使用
```

## 分发机制

- 以 `coreutils` 之名运行 → 显示用法；`--coreutils-prog=PROG` → 运行 PROG
- 软链名命中内建程序表 → 按单程序运行；表外名字报 `unknown program`（退出码 1）
- `[`、`test`、`install`（内部分发名 ginstall）等均已处理
- 版本查询：`"$C" --version`；单程序版本：`"$C" --coreutils-prog=ls --version`

## 内建程序（102 个，`coreutils --help` 可查）

```
[ b2sum base32 base64 basename basenc cat chgrp chmod chown chroot cksum comm cp csplit
cut date dd df dir dircolors dirname du echo env expand expr factor false fmt fold ginstall
groups head hostid id join link ln logname ls md5sum mkdir mkfifo mknod mktemp mv nice nl
nohup nproc numfmt od paste pathchk pinky pr printenv printf ptx pwd readlink realpath rm
rmdir seq sha1sum sha224sum sha256sum sha384sum sha512sum shred shuf sleep sort split stat
stdbuf stty sum sync tac tail tee test timeout touch tr true truncate tsort tty uname
unexpand uniq unlink users vdir wc who whoami yes
```

## 高频场景速查

| 场景 | 示例 |
|---|---|
| 版本序/人类大小排序 | `sort -V`、`sort -h`、`sort -R`（随机） |
| 列目录 | `ls --color=auto -lh`、`ls -la --time-style=long-iso` |
| 时间计算 | `date -d "yesterday"`、`date -d @1700000000`、`date -u +%FT%TZ` |
| 取头尾 | `head -n -5`（去掉末 5 行）、`tail -n +3` |
| 文本处理 | `cut -d, -f2-`、`tr -d '\r'`、`uniq -c`、`tac`、`shuf` |
| 校验和 | `sha256sum`、`cksum`、`b2sum` |
| 大文件 | `split -b 100M`、`truncate -s 1G`、`dd bs=1M count=10` |
| 路径 | `realpath -m`、`readlink`、`basename`/`dirname` |
| 进程/系统 | `nproc`、`timeout 5 cmd`、`sleep 0.5`、`nice -n 10`、`nohup` |
| 数值 | `seq -w 1 10`、`numfmt --to=iec 1073741824`、`factor` |

## 退出码

- 各程序遵循自身标准约定（如 `sort -c` 乱序=1、`timeout` 超时=124、`test` 布尔结果=0/1）
- 分发器层：未知程序名 = 1

## iSH 注意事项

- 全静态 musl 构建，无外部依赖；同文件可复制到任何 Linux aarch64/amd64 机器
- 体积：约 0.65 MB（arm64）/ 0.68 MB（amd64），UPX 压缩后
- 静态精简构建**不含** ACL / xattr / SELinux / 多国语言支持
- 与 busybox 同为多路复用单文件，但这是 **GNU 实现**：GNU 语义与扩展全量可用（`sort -V`、`ls --color`、`date -d`、`head -n -5` 等）
- 与系统/busybox 命令共存互不影响：软链法可只让需要的命令走 GNU 版（PATH 顺序决定）

## 相关工具

- `busybox`（同形态多路复用；轻、快、applet 更广）
- `grep` / `sed` / `find` / `xargs` / `diff` / `tar` / `xz` / `zip`（工具箱里各自的 GNU/官方实现，与之配套）
