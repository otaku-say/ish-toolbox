# socat —— 双向数据中继（TCP/TLS/UNIX/PTY 配方）

把两个"地址"对接：`socat [选项] <左地址> <右地址>`。Agent 场景：裸 HTTP/TLS 试探、把命令挂进 PTY、本地回环试验、临时服务器。本机 1.8.1.3，编译含 OPENSSL/PTY/EXEC/UNIX 等（`socat -V` 实测可见）。

## 推荐用法

```sh
# 裸 HTTP（TCP4 直连；-T 10 = 不活动 10 秒自动结束）
printf 'GET / HTTP/1.0\r\nHost: example.com\r\n\r\n' | timeout 20 socat -T 10 - TCP4:example.com:80

# TLS 客户端（verify=0 跳过证书校验，仅测试用；实测返回 HTTP/1.1 200 OK）
printf 'GET / HTTP/1.0\r\nHost: example.com\r\n\r\n' | timeout 20 socat -T 10 - OPENSSL:example.com:443,verify=0
```

```sh
# PTY 配方：让命令自认终端（实测 isatty 为真）
cat > /tmp/istty.sh <<'EOF'
#!/bin/sh
[ -t 0 ] && echo STDIN-IS-TTY || echo STDIN-NOT-TTY
[ -t 1 ] && echo STDOUT-IS-TTY || echo STDOUT-NOT-TTY
EOF
chmod +x /tmp/istty.sh
printf '' | timeout 8 socat -T 3 - EXEC:/tmp/istty.sh,pty,raw,echo=0
# 实测输出：STDIN-IS-TTY / STDOUT-IS-TTY（不加 pty 则都是 NOT-TTY）

# PTY 下 sed 的已知行为：每行延迟一行、尾行悬置 —— 补哨兵行顶出
printf '1\n2\n3\nSENTINEL\n' | timeout 8 socat -T 3 - EXEC:'sed s/^/X/',pty,raw,echo=0
# 实测输出：X1 / X2 / X3；"XSENTINEL" 被留在缓冲里（哨兵自己也被悬置）
```

```sh
# 本地回环：左侧收进文件（后台），右侧发（前台）
timeout 6 socat -u UNIX-LISTEN:/tmp/demo.sock - > /tmp/demo_recv.txt &
sleep 1
printf 'hi\n' | timeout 5 socat -T 3 - UNIX-CONNECT:/tmp/demo.sock
wait; cat /tmp/demo_recv.txt    # → hi
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-V` | 版本 + 编译特性列表（实测含 WITH_OPENSSL / WITH_PTY / WITH_EXEC / WITH_UNIX） |
| `-h` / `-hh` / `-hhh` | 帮助（-hh 加常用地址选项名，-hhh 全量） |
| `-d -d` | 日志诊断（实测输出 EOF / 不活动超时 / 退出原因） |
| `-T <秒>` | 不活动超时；左右任一无数据即计时，到点退出（实测） |
| `-u` | 单向：左 → 右（实测收文件） |

## 地址速查（均为实测过的组合）

| 地址 | 用途 |
|---|---|
| `-` | stdin/stdout |
| `TCP4:host:port` | TCP 客户端（IPv4） |
| `TCP-LISTEN:port[,reuseaddr]` | TCP 服务器（实测能被 scp 等客户端连上） |
| `OPENSSL:host:port[,verify=0]` | TLS 客户端 |
| `EXEC:cmd[,pty,raw,echo=0]` | 拉起进程；PTY 配方见上 |
| `UNIX-LISTEN:<路径>` / `UNIX-CONNECT:<路径>` | UNIX 域套接字 |
| `UDP:` `SOCKS4/5:` `PROXY:` | 编译已含（`-V` 可见）；**未实测** |

## 退出码

- `0` = 正常结束（含 `-T` 不活动超时退出；注意此时缓冲尾行可能已丢，实测）
- `1` = 连接失败等错误（实测 Connection refused → rc=1，日志 `E TCP4:…: Connection refused`）
- `143` = 被 busybox `timeout` 击杀（iSH 语义）

## iSH 注意事项

- **一切可能挂住的用法都套 `timeout N`**；网络用途再加 `-T` 双保险。被击杀 = 143。
- PTY 固定配方 `socat - EXEC:'cmd',pty,raw,echo=0`（实测能挂进 PTY）；漏掉 `echo=0` 会混入输入回显，输出不可信。
- PTY 已知行为：每行延迟一行、**尾行悬置**（补一行哨兵顶出；哨兵自己被悬置）；**iconv 经 PTY 全灭**（实测输出为空）——需要 iconv 就不要过 PTY。
- `-T` 退出时可能丢弃未刷出的缓冲（实测 sed 尾行丢失）；重要尾部数据补哨兵或靠 EOF 驱动。
- 诊断加 `-d -d`；退出原因（EOF / inactivity）都会打日志。
- 静态 musl 二进制；DNS 仍走 `/etc/resolv.conf`（iOS 托管，别改）。

## 相关工具

- `curl` / `openssl` —— HTTP 与 TLS 的完整选择（socat 适合"裸探"）
- `faketty` —— 单一用途的 PTY 包装，简单场景更顺手
- `ssh` / `scp` / `sftp` —— SSH 侧传输
- `drill` —— DNS 排查（网络问题先查这里）
