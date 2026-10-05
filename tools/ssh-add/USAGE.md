# ssh-add —— 向 ssh-agent 添加/管理密钥

在**已有可用代理**的前提下操作密钥：加、列、删、限时、锁。靠 `SSH_AUTH_SOCK` 环境变量找代理——iSH 上该变量只在同一 shell 里存在（先看 ssh-agent 文档）。

## 推荐用法

```sh
# 一条命令里走完：起代理 → 造钥匙 → 装 → 查 → 清
eval "$(ssh-agent -s)"
mkdir -p /tmp/add_demo && ssh-keygen -q -t ed25519 -f /tmp/add_demo/id -N '' -C demo
ssh-add /tmp/add_demo/id     # Identity added: /tmp/add_demo/id (demo)
ssh-add -l                   # 256 SHA256:… demo (ED25519)
ssh-add -D                   # All identities removed.
ssh-agent -k
```

```sh
# 带密码的私钥：从 stdin 喂密码（实测可行）
ssh-keygen -q -t ed25519 -f /tmp/add_demo/idp -N 'pw9' -C tp
printf 'pw9\n' | ssh-add /tmp/add_demo/idp    # Identity added: … (tp)

# 检查公钥是否已装入（实测 rc=0 = 已装入）
ssh-add -T /tmp/add_demo/id.pub

# 限时钥匙（秒）；到期自动从列表消失
ssh-add -t 300 /tmp/add_demo/id

# 锁/解锁代理：-x 要输两遍密码、-X 一遍（非交互用 printf 实测可行）
printf 'lockpw\nlockpw\n' | ssh-add -x    # Agent locked.
printf 'lockpw\n' | ssh-add -X            # Agent unlocked.
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-l` | 列出指纹（默认 SHA256） |
| `-L` | 列出公钥全文 |
| `-E md5` | 配合 `-l`/`-L` 指定指纹算法（实测） |
| `-d <文件>` | 删除单个（`Identity removed: …`，实测） |
| `-D` | 删除全部（`All identities removed.`，实测） |
| `-t <秒>` | 寿命（实测 2 秒后自动消失） |
| `-T <公钥>` | 检查该公钥是否在代理里（实测已装入 rc=0） |
| `-x` / `-X` | 锁定 / 解锁代理（实测：-x 两遍密码、-X 一遍） |

## 退出码

- `0` = 成功
- `1` = 代理里没有身份（`-l` 实测；空 / 锁定 / 过期都是 1）
- `2` = 连不上代理（实测：无 SSH_AUTH_SOCK 时）

## iSH 注意事项

- 前提是**当前进程**环境里有 `SSH_AUTH_SOCK`：新 shell_execute 里直接跑 → `Could not open a connection …` rc=2（实测）。同一命令先 `eval "$(ssh-agent -s)"`。
- 测试私钥放 /tmp 或 mktemp -d；不要动 `~/.ssh` 已有钥匙。
- `printf 'pw\n' | ssh-add` 实测可用（无 tty 时读 stdin），但密码会经过管道/进程——敏感场景改用交互终端（[Open Terminal](minis://open_terminal)）。
- agent 一旦被回收/杀掉，装入的钥匙全部失效——随用随装。
- `-l` 空代理 rc=1：脚本里别用 `&&` 串联，接 `;` 或 `|| true`。

## 相关工具

- `ssh-agent` —— 前置依赖（起代理）
- `ssh-keygen` —— 造钥匙 / 指纹
- `ssh` —— 消费被代理的钥匙
