# faketty —— 把命令的 stdout 挂进伪终端（PTY）

让"只认终端"的程序以为自己在 TTY 里跑：颜色自动开、走上行缓冲、`[ -t 1 ]` 为真。
iSH 上 `stdbuf` 对 stdout **无效**（平台级 setvbuf 失效），需要终端语义时用它顶上。

本份二进制含 **iSH 修复补丁**（原版会挂死并泄漏进程），已真机验证。

## 推荐用法

```sh
# 1) 让子进程自认 stdout 是终端
timeout 8 faketty sh -c '[ -t 1 ] && echo IS_TTY || echo NOT_TTY'     # IS_TTY

# 2) 管道里给颜色程序一个"终端"（否则它们会自动关色）
timeout 8 faketty sh -c 'printf "\033[31mRED\033[0m\n"' | od -c       # ESC 序列原样保留

# 3) 退出码原样透传（可以拿它判断成败）
timeout 8 faketty sh -c 'exit 42'; echo $?                            # 42

# 4) 把 PTY 输出的 \r 剥掉（在消费端做，别指望它不出）
timeout 8 faketty cat <<< $'a\nb' 2>/dev/null | tr -d '\r'

# 5) 版本
faketty --version                                                     # faketty 1.0.20
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `--version` | 打印版本 |
| （无其它选项） | 用法就是 `faketty <程序> [参数…]` |

`-h` 不被接受，会报 `error: unexpected argument '-h' found`。

## 行为契约

- **只把 stdout 接进 PTY**：`[ -t 1 ]` 为真；stdin 不保证（实测报非终端），stderr 同理。
- 输出走终端语义：`\n` 被转成 `\r\n`（ONLCR）。要干净文本就在**消费端** `tr -d '\r'`。
- 转义序列（ANSI 颜色）原样透传。
- **退出码原样透传**（多层包装也准）。

## iSH 注意事项

- 本份二进制含 **iSH 挂死修复补丁**：原版 1.0.20 在 iSH 上子进程退出后**自己不退出**（pty 主端不发 EIO/EOF），每跑一次泄漏进程；补丁改为 `poll(100ms)` + `waitpid(WNOHANG)` 收尾。实测：退出码透传正常、连续运行后**残留进程 0**。
- 判据：**如果看到 `rc=143`**（被 `timeout` 兜底击杀），说明手上是没打补丁的老二进制——换成仓库版即可。
- 数据期的观感仍是"每行延迟一行"（iSH 的 stdio 层特性，PTY 改不了）。**不要拿它做实时时序实验**，它只解决"是不是终端"。
- 老版泄漏的进程是常驻的，用 `ps | grep faketty` 找出来 `kill -9` 清掉；升级后不再产生。
- **别被 iSH 的进程表骗了**：刚跑完立刻 `ps`，可能还看到 1 条 faketty——那是进程表约 1s 的更新延迟，**等一拍就消失**，不是泄漏。判断有无泄漏请隔 1 秒再数。

## 相关工具

- `socat` —— PTY 配方（`socat - EXEC:'cmd',pty,raw,echo=0`），需要更细的双向控制时用
- `chronic` —— 只想要"成功静默、失败回放"的包装，用它（不做 TTY 伪装）
- `tini` —— 需要信号转发 / 收尸时用它
