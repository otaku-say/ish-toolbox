# tmux（3.7c，全静态）

> 一行定位：终端复用器——会话常驻后台、随时进出；Agent 用它托管长任务、读屏抓输出。

## 推荐用法（可原样复制）

```sh
tmux new -s work                      # 新建会话并进入（Ctrl+B d 脱离）
tmux new -d -s bg 'sleep 100'         # 后台起会话跑命令（-d = 不进入）
tmux ls                               # 列出所有会话
tmux attach -t bg                     # 进入会话
tmux send-keys -t bg 'echo hi' Enter  # 向会话注入按键（Agent 常用）
tmux capture-pane -p -t bg            # 抓取当前屏幕文本到 stdout（Agent 读输出）
tmux kill-session -t bg               # 结束会话
tmux kill-server                      # 结束全部会话与服务
```

## 常用参数

| 参数 | 说明 |
|---|---|
| `new -s <名>` | 新建命名会话 |
| `new -d -s <名> <命令>` | 后台建会话直接跑命令 |
| `attach -t <名>` | 接入会话（`-d` 强制其它客户端脱离） |
| `send-keys -t <名> [键…]` | 注入按键（`Enter`/`C-c` 等转义名可用） |
| `capture-pane -p -t <名>` | 抓屏到 stdout（`-S -200` 含回滚缓冲） |
| `ls` / `kill-server` | 列出会话 / 全部结束 |

## 退出码与错误处理

- `0` 成功；`1` 失败（如 `no server running on ...`、`can't find session: <名>`）
- 会话不存在时 `attach`/`send-keys` 会报 `can't find session`——先 `tmux ls` 探活
- `capture-pane` 对空面板输出空行（正常，不是错误）

## iSH 注意事项

- **本构建含 iSH 专属补丁（tmux-ishfix.patch）**：iSH 未实现 SCM_RIGHTS（fd 随 unix socket 传递），原版 tmux `attach` 会报 `open terminal failed: not a terminal`。补丁在服务端收不到 fd 时按 `ttyname` 直开客户端终端（tmux 自身给 Cygwin 的兜底思路）。**attach 全流程已在 iSH 真机验证**（画面渲染/按键/capture 均正常）；正常 Linux 上该分支不生效。
- 会话 socket 放 `$TMUX_TMPDIR`（默认 `/tmp`）；iPhone 重启或 App 重装会清空 `/tmp` → 会话不跨重启。
- App 切后台期间进程冻结：tmux 的"常驻"仅在 App 活跃期间有效（iOS 平台限制）。
- 前缀键默认 `Ctrl+B`（`d` 脱离、`c` 新窗口、`[` 翻页）；iOS 软键盘需切扩展键盘才能按 Ctrl。
- 终端能力：ncurses 内嵌常用 terminfo fallback（xterm-256color/screen/tmux-256color 等），系统缺 terminfo 也能正常渲染。

## 相关工具

`faketty`（无 tty 环境 PTY 伪装）、`tini`（信号转发 + 收尸）、`chronic`（成功静默/失败回放）——托管任务三件套。
