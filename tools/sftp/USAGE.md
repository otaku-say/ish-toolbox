# sftp —— SFTP 传输客户端（批处理优先；外置调用 /usr/local/bin/ssh）

与 scp 同机制：把会话交给外部 ssh 程序（编译期固定 `/usr/local/bin/ssh`），依赖工具箱注册。Agent 用法以批处理模式（`-b`）为主，交互式模式留给人。

## 推荐用法

```sh
# 批处理文件（脚本首选）：连接后按文件逐条执行远端命令
mkdir -p /tmp/sftp_demo && printf 'pwd\n' > /tmp/sftp_demo/batch.txt
timeout 25 sftp -o BatchMode=yes -o ConnectTimeout=10 \
  -o UserKnownHostsFile=/tmp/sftp_demo/kh -o StrictHostKeyChecking=accept-new \
  -b /tmp/sftp_demo/batch.txt git@github.com

# 同一批命令从 stdin 进（-b -），实测等价（到 github 认证失败 rc=255）
printf 'pwd\n' | timeout 25 sftp -o BatchMode=yes -o ConnectTimeout=10 \
  -o UserKnownHostsFile=/tmp/sftp_demo/kh -o StrictHostKeyChecking=accept-new \
  -b - git@github.com

# 验证外置 ssh 依赖：-S 指向不存在的程序 → 立即报 exec 错误
timeout 10 sftp -S /nonexistent/ssh -b /tmp/sftp_demo/batch.txt git@github.com; echo "rc=$?"
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-b <文件\|->` | 批处理模式；`-` 表示读 stdin（实测） |
| `-o <键=值>` | 透传 ssh 配置（实测 BatchMode / ConnectTimeout / …） |
| `-v` | 详细调试；实测可见 `Connection established` / `Permission denied`（debug 行来自 ssh 子进程） |
| `-S <程序>` | 指定 ssh 程序（默认 /usr/local/bin/ssh） |
| `-i <私钥>` | 指定私钥（实测以 `-i <路径>` 传给 ssh） |
| `-P <端口>` | 端口（实测以 `-oPort <n>` 传给 ssh） |
| `-B` / `-R` / `-r` | 缓冲 / 并发请求数 / 递归 get·put（**未验证**：无服务器） |

批处理文件内的远端命令（get/put/ls/mkdir/rm…）为标准 OpenSSH sftp 命令；**未验证**（本机无服务器，未能跑通成功会话）。

## 退出码

- `255` ssh/传输层错误（实测：认证失败、ssh 程序缺失均 255）
- `143` 被 `timeout` 击杀（iSH 语义）
- `0` 成功（未验证：本机无 sshd）

## iSH 注意事项

- 依赖 `/usr/local/bin/ssh`（见 scp 文档同款证据链）：`-S /nonexistent/ssh` 实测报 `exec: …: No such file or directory`。注册检查 `ls -l /usr/local/bin/ssh`；重置后 `sh /var/minis/skills/ish-toolbox/bin/install.sh`。
- 注意：`sftp -v` **不像 scp 那样打印 “Executing:” 行**（实测没有）；验证依赖请用 `-S` 负例或 scp 侧输出。
- 首次连接 accept-new / ssh-keyscan；known_hosts 默认写 `/root/.ssh/`（可用 `-o UserKnownHostsFile` 重定向）。
- 交互模式（不带 `-b`）从 stdin 收命令，易与 Agent 管道打架——统一用 `-b`。
- 全部套 `timeout`；143 = 被击杀。
- 本机无 sshd：未演示成功 get/put 路径。

## 相关工具

- `scp` —— 单次/递归拷贝，脚本化更简单
- `ssh` —— 连接本体（sftp 的运行依赖）
- `ssh-keyscan` / `ssh-keygen` —— known_hosts 与密钥
- `socat` —— 起临时本地服务用于联调
