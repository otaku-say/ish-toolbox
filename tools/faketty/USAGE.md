# faketty —— 给命令套一个伪终端（PTY）

faketty 1.0.20。让"只认终端"的程序（颜色、行缓冲、`[ -t 1 ]` 判断）以为自己在 TTY 里跑。iSH 上 `stdbuf` 对 stdout 无效，需要终端语义时用它。

> ⚠️ 实测本机这份二进制**子进程退出后自己不退出**：连 `timeout 15 faketty true` 都会被挂住杀掉。**所有用法一律用 `timeout N` 包住。**

## 推荐用法

```sh
# 1) 让程序自认 stdout 是终端（对比：不加 faketty 时是 NOT_TTY）
timeout 3 faketty sh -c '[ -t 1 ] && echo IS_TTY || echo NOT_TTY'
# IS_TTY

# 2) 用 PTY 跑命令，管道喂输入（输出带 \r\n）
printf 'hi\n' | timeout 3 faketty cat

# 3) 剥掉 PTY 的 \r（在消费端做），od 里确认只剩 \n
printf 'a\nb\n' | timeout 3 faketty cat 2>/dev/null | tr -d '\r' | od -c
# 0000000   a  \n   b  \n

# 4) 内部命令退出码在外层拿不到（被 timeout 杀掉恒 143）：
#    让内层自己写文件
timeout 3 faketty sh -c 'false; echo $? > rc' 2>/dev/null; cat rc
# 1

# 5) 唯一不挂死的路径：--version（不启动子进程）
timeout 5 faketty --version
# faketty 1.0.20
```

## 常用参数

faketty 没有选项：`faketty <program> <args...>`；唯一旗标是 `--version`。
`-h` 会报错：`error: unexpected argument '-h' found`（退出码 2）。

## 退出码 / 错误处理

- 实测外层恒为 **143**（子进程退出后 faketty 被 timeout SIGTERM）：**不能**用外层退出码判断内部命令成败
- 判成败看输出，或让内层写文件：`timeout N faketty sh -c 'cmd; echo $? > rc'` 然后 `cat rc`

## iSH 注意事项

- 所有调用都套 `timeout N`（本机挂死 bug，见开头警示）；N 取"命令预期时间 + 余量"。
- PTY 输出按终端语义带 `\r\n`；进日志/比较前先 `tr -d '\r'`（实测 od 可证）。
- 管道输入→PTY 正常：`printf … | faketty cat` 内容完整回显。
- 需要精确退出码的流程别用它；那种场景考虑 socat 的 PTY 配方，或直接改写命令避开 TTY 依赖。
- 注意：timeout 杀掉它时 shell 可能多打一行 `Terminated`，是正常噪音。

## 相关工具

- `socat` —— 需要精细的 PTY 双向控制时（`socat - EXEC:'cmd',pty,raw,echo=0`）
- `chronic` —— 只是想要"成功静默、失败回放"的包装时，用它别用 faketty
