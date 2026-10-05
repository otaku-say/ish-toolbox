# su-exec —— 以指定用户:组身份执行单条命令

nxhack su-exec。setuid/setgid 后直接 exec 目标命令，参数是 `user[:group]`（名字或数字），不是 `-u 用户` 选项。脚本/容器里降权跑单个命令用它；不要拿它当登录工具（没有 su/login 的环境初始化）。

## 推荐用法

```sh
# 0) 先看当前身份（iSH 默认 root）
id

# 1) 只给用户：使用其主组
su-exec nobody id
# uid=65534(nobody) gid=65534(nobody) groups=65534(nobody)

# 2) 用户:组 显式指定（名字/数字都支持，数字不要求 /etc/passwd 里有）
su-exec nobody:nobody id
su-exec 12345:12345 id

# 3) 降权执行；命令退出码原样透传（实测 exit 7 → 7）
su-exec nobody sh -c 'exit 7'; echo $?

# 4) root 身份执行（0:0）
su-exec 0:0 echo hi
```

## 常用参数（位置参数，不是选项）

| 形式 | 作用 |
|---|---|
| `user` | 目标用户（名字或数字 uid），用其主组 |
| `user:group` | 组可用名字或数字；两者都可混用 |
| `command [args...]` | 要执行的命令及参数 |

## 退出码 / 错误处理

- 目标命令的退出码原样返回（exec 语义，实测）
- `1` = 用户不存在：`su-exec: getpwnam(nosuchuser999): Invalid argument`
- `1` = 命令找不到：`su-exec: /no/such/cmd: No such file or directory`
- 无参数时打印 `Usage: su-exec user-spec command [args]`，退出码 1

## iSH 注意事项

- iSH 里一切进程默认以 root 跑（单用户环境），su-exec 的意义是**主动降权**，用来模拟普通用户/容器行为。
- 没有 `-u` 选项：`su-exec -u nobody id` 会把 `-u` 当用户名，报 `getpwnam` 失败（实测）。
- 降权后读写文件受目标目录权限约束：nobody 对 root 拥有的目录（如 /root、技能目录）写不了。
- 仅影响这一条命令，不改变当前 shell 身份；不需要也不接受密码。

## 相关工具

- `ssh` —— 远程机器上的身份切换用 ssh 登录
- `tini` —— 作为 PID 1 收孤儿进程/转发信号用它，不是 su-exec 的替代
