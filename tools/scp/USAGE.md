# scp —— SSH 文件拷贝（外置调用 /usr/local/bin/ssh）

scp 自己不实现网络：运行时 exec 外部 ssh 程序（编译期固定 `/usr/local/bin/ssh`，实测 `scp -v` 可见），现代默认协议为 SFTP（`ssh … -s -- host sftp`）。

**前置依赖**：工具箱已注册（`/usr/local/bin/ssh` 存在）才能用；缺失时立即报 `exec: … No such file or directory`。

## 推荐用法

```sh
# 上传测试（到 github 必然认证失败 rc=255，用来验证链路与依赖）
mkdir -p /tmp/scp_demo && printf 'hi\n' > /tmp/scp_demo/f.txt
timeout 25 scp -o BatchMode=yes -o ConnectTimeout=10 \
  -o UserKnownHostsFile=/tmp/scp_demo/kh -o StrictHostKeyChecking=accept-new \
  /tmp/scp_demo/f.txt git@github.com:/tmp/

# 看它调用了谁（应出现 Executing: program /usr/local/bin/ssh … command sftp）
timeout 25 scp -v -o BatchMode=yes -o UserKnownHostsFile=/tmp/scp_demo/kh \
  -o StrictHostKeyChecking=accept-new /tmp/scp_demo/f.txt git@github.com:/tmp/ 2>&1 | grep Executing

# 模拟「工具箱未注册」（-S 指向不存在的 ssh）：立即失败、不碰网络
timeout 10 scp -S /nonexistent/ssh /tmp/scp_demo/f.txt git@github.com:/tmp/; echo "rc=$?"

# 注册状态自查
ls -l /usr/local/bin/ssh
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-v` | 详细输出；可见 `Executing: program /usr/local/bin/ssh … command sftp` |
| `-o <键=值>` | 透传 ssh 配置（BatchMode / ConnectTimeout / StrictHostKeyChecking / UserKnownHostsFile） |
| `-P <端口>` | 目标端口（大写 P；实测可用） |
| `-i <私钥>` | 指定私钥（实测以 `-i <路径>` 追加进 ssh 参数） |
| `-S <程序>` | 指定 ssh 程序（默认 /usr/local/bin/ssh；也可注入假 ssh 联调） |
| `-O` | 回退传统 SCP 协议（实测把 `sftp` 子命令换成 `scp -t`；老服务器才需要） |
| `-r` | 递归拷贝目录（**未验证**：本机无 sshd，未跑通成功路径） |
| `-p` | 保留时间戳/权限（**未验证**） |
| `-C` | 压缩传输（**未验证**） |

## 退出码

- `255` ssh/传输层错误（认证失败、连接被拒均实测 255）
- `143` 被 `timeout` 击杀（iSH 语义）
- `0` 成功（未验证：本机无 sshd 成功场景）

## iSH 注意事项

- **依赖链**：`scp → /usr/local/bin/ssh`（编译期常量，实测精简 PATH 后依然调用该路径）。未注册时报 `exec: … No such file or directory`（用 `-S /nonexistent/ssh` 实测同一形态）。
- 首次连接加 `-o StrictHostKeyChecking=accept-new`（或先 ssh-keyscan）；ask 模式非终端直接失败。
- known_hosts 默认写 `/root/.ssh/`（无目录会自建）；保持隔离用 `-o UserKnownHostsFile=/tmp/...`。
- 网络用例全部套 `timeout`；卡住被击杀 = 143。
- 本机没有 sshd：成功拷贝/递归等"绿路径"无法演示，本文网络用例以"认证失败 = 链路通"为准。

## 相关工具

- `sftp` —— 批处理/交互式传输（同一依赖）
- `ssh` —— 连接本体（scp 的运行依赖）
- `ssh-keyscan` / `ssh-keygen` —— known_hosts 与密钥
- 本机无 rsync；批量同步用 `scp -r` 或 tar 流经 ssh
