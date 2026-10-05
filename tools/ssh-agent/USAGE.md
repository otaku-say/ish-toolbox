# ssh-agent —— 密钥代理（iSH 关键：同一 shell 内 eval）

把私钥缓存进内存供 ssh 使用。**iSH 上每条 shell_execute 都是新进程**：`SSH_AUTH_SOCK` / `SSH_AGENT_PID` 不会带到下一条命令，所以标准姿势是 `eval $(ssh-agent -s)` 之后**在同一命令里**完成"起代理 → 装钥匙 → 用 → 清理"。

## 推荐用法

```sh
# 标准姿势：起代理，同一 shell 内继续操作（eval 让环境变量生效）
eval "$(ssh-agent -s)"
ssh-add -l        # 空代理 → "The agent has no identities."（rc=1）
ssh-agent -k      # 收尾：杀掉当前代理（输出 unset …; Agent pid N killed; rc=0）
```

```sh
# 指定 socket 路径（默认在 /root/.ssh/agent/ 下，见注意事项）
eval "$(ssh-agent -a /tmp/agent_demo.sock -s)"
echo "$SSH_AUTH_SOCK"    # → /tmp/agent_demo.sock
ssh-agent -k

# 设置默认密钥寿命：此后 ssh-add 装入的钥匙 2 秒自动过期（实测）
eval "$(ssh-agent -t 2 -s)"
```

```sh
# 跨命令复用（不推荐，但实测可行）：环境存文件，下条命令 source
ssh-agent -s > /tmp/agent_demo.env      # 命令 A
. /tmp/agent_demo.env; ssh-add -l       # 命令 B：可达旧代理（空则 rc=1）
ssh-agent -k                            # 用完杀掉，防残留
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-s` | 输出 sh 语法环境（配 eval；实测格式 `SSH_AUTH_SOCK=…; export …`） |
| `-k` | 杀掉当前环境变量指向的代理（rc=0，实测） |
| `-a <路径>` | 指定 socket 路径（实测） |
| `-t <秒>` | 后续加入密钥的默认寿命（实测：2 秒后列表为空） |
| `-V` | 版本（OpenSSH_10.5, LibreSSL 4.3.3） |

## 退出码

- `0` = 启动/关闭成功（实测）
- 后续命令连不上代理：`ssh-add -l` 报 `Could not open a connection to your authentication agent.` 且 rc=2（实测）

## iSH 注意事项

- **不跨命令存活**（环境变量层面）：不 eval 时，下一条命令里 `ssh-add` 报 `Could not open a connection …`（rc=2，实测）。要在同一 shell 里 `eval "$(ssh-agent -s)"` 使用。
- 代理**守护进程**本身可能跨命令存活（实测 PID 仍在），但环境变量不继承；想复用就把 `-s` 输出存文件后 source（实测可达）；否则每个命令新起一个会残留累积。
- 默认 socket 不在 /tmp：实测为 `/root/.ssh/agent/s.<id>.agent.<id>`（ssh-agent 会把 `/root/.ssh` 建出来）。要放别处用 `-a`。
- `ssh-agent -k` 依赖当前 shell 里的 `SSH_AGENT_PID`；偶发信号处理延迟未退出时直接 `kill $SSH_AGENT_PID`。
- 清理意识：用完 `-k` 或 kill，避免多个后台代理长期堆积。
- iSH 无 systemd 等常驻管理：随用随起随收，不要当"服务"跑。

## 相关工具

- `ssh-add` —— 装/查/删密钥（本代理的操作面）
- `ssh` —— 消费 agent 的钥匙
- `ssh-keygen` —— 造测试密钥
