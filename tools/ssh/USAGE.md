# ssh —— OpenSSH 客户端（远程登录 / 执行 / 隧道）

> OpenSSH_10.5p1，LibreSSL 4.3.3（`ssh -V` 实测）。二进制 `/usr/local/bin/ssh → ish-toolbox/tools/ssh/arm64/ssh`。

Agent 场景：连通性测试、非交互执行远程命令、`-G` 检查生效配置。文件传输用 scp/sftp；主机公钥预采用 ssh-keyscan。

## 推荐用法

```sh
# 连通性测试（github 认证失败 rc=255 = 链路通；accept-new 免首次交互卡住）
timeout 20 ssh -T -o BatchMode=yes -o ConnectTimeout=10 \
  -o UserKnownHostsFile=/tmp/ssh_demo_kh -o StrictHostKeyChecking=accept-new git@github.com

# 指定私钥连接（密钥不必放 ~/.ssh）
timeout 20 ssh -i /tmp/kg_demo/id -T -o BatchMode=yes -o ConnectTimeout=10 \
  -o UserKnownHostsFile=/tmp/ssh_demo_kh -o StrictHostKeyChecking=accept-new git@github.com

# 查看最终生效的配置（不发起连接）
ssh -G -p 2222 github.com | grep -E '^(port|user) '

# 排错：确认密钥被提供给服务器
timeout 20 ssh -v -i /tmp/kg_demo/id -T -o BatchMode=yes -o ConnectTimeout=10 \
  -o UserKnownHostsFile=/tmp/ssh_demo_kh -o StrictHostKeyChecking=accept-new git@github.com 2>&1 | grep -E 'Offering|denied'

# 算法能力查询
ssh -Q key | head -6

# 非交互执行远程命令（成功路径需自有服务器；本机无，未验证）
timeout 20 ssh -T -o BatchMode=yes user@host 'uname -a'
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-T` | 禁用 PTY；非交互必加（不加且 stdin 非终端时会多出 Pseudo-terminal 警告，实测） |
| `-v` / `-vvv` | 调试输出；`-v` 实测能看到 Offering public key |
| `-i <文件>` | 指定私钥 |
| `-o <键=值>` | 覆盖配置；实测常用 BatchMode / ConnectTimeout / StrictHostKeyChecking / UserKnownHostsFile |
| `-p <端口>` | 目标端口 |
| `-G <主机>` | 只 dump 最终生效配置，不连接（实测 `-p 2222` 会反映到 port 行） |
| `-Q <类型>` | 查询算法列表（key / cipher / kex …） |
| `-V` | 版本（OpenSSH_10.5p1, LibreSSL 4.3.3） |

隧道/跳板（-L/-R/-D/-J/-N/-W）等需可用服务器，本机未实测，不展开。

## 退出码

- `255` ssh 自身错误：认证失败 / 连接被拒 / 连接超时（三种均实测）
- `143` 被 busybox `timeout` 击杀（iSH 语义，实测；不要按 GNU 的 124 判断）
- `0` 远程命令成功、远程命令退出码透传（均未验证：本机无可用服务器）

## iSH 注意事项

- 首次连接加 `-o StrictHostKeyChecking=accept-new` 或先 `ssh-keyscan`。默认 `ask` 在非终端直接失败（实测：`Host key verification failed.` rc=255）。
- `~/.ssh` 不存在时 ssh 会自建目录并写 `/root/.ssh/known_hosts`（实测）；要零污染用 `-o UserKnownHostsFile=/tmp/xxx` 重定向。
- 网络命令一律套 `timeout N`；被击杀返回 143。
- DNS 读 `/etc/resolv.conf`（由 iOS 托管，别改）；解析失败先换 IP/端口排查。
- `BatchMode=yes` 防止任何交互提示挂住，Agent 场景建议默认加。
- 纯静态二进制、无 wrapper：`readlink /usr/local/bin/ssh` 核对；重置后 `sh /var/minis/skills/ish-toolbox/bin/install.sh` 重新注册。

## 相关工具

- `scp` / `sftp` —— 文件传输（都外置调用本 ssh）
- `ssh-keygen` —— 密钥生成/指纹
- `ssh-keyscan` —— 预采主机公钥
- `ssh-agent` / `ssh-add` —— 密钥代理
- `socat` —— 裸 TCP/TLS 直连调试
