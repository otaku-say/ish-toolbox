# chronic —— 命令成功则静默、失败才回放输出

给定时任务/日检脚本**降噪**的包装器：命令成功时零输出，失败时把 stdout/stderr 原样回放并透传退出码。
写 cron、写"每天自检"类脚本时用它，日志里只剩真正出事的那几次。

语义对齐 moreutils 的 `chronic`（0.70）；本实现是 C 版，并做了若干加固（见下）。

## 推荐用法

```sh
# 1) Agent 防卡死标准写法：成功静默 / 失败打印 / 执行受界
chronic timeout 10s sh -c 'do_something' < /dev/null

# 2) 成功：什么都不打印（rc=0）
chronic true; echo $?                      # （无输出）0

# 3) 失败：原样回放输出，退出码透传
chronic sh -c 'echo "boom" >&2; exit 3'    # 输出 boom；rc=3

# 4) 冗长模式：失败时给 stdout/stderr 分段标签 + RETVAL
chronic -v sh -c 'echo out; echo err >&2; exit 4'

# 5) 命令成功但 stderr 非空也算"有事"→ 回放并以 2 退出
chronic -e sh -c 'echo warn >&2'           # rc=2

# 6) 选项只写在命令之前；命令自身的选项用 -- 隔开
chronic -v -- mycmd --verbose

# 7) 版本 / 帮助
chronic --version                          # chronic 1.3
chronic --help
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-v` | 冗长：失败时输出带 `STDOUT`/`STDERR` 分段标签 + `RETVAL` |
| `-e` | stderr 触发：命令**成功但 stderr 非空** → 回放并以 `2` 退出 |
| `--` | 终止选项解析，后面整串都当命令 |
| `--help` / `--version` | 帮助 / 版本（rc=0） |

支持组合：`-ve` 等价于 `-v -e`。

## 退出码 / 错误处理

- **命令的退出码原样透传**（0 成功 / 非 0 失败）。
- `-e` 命中时返回 **2**（不是命令原来的 0）。
- 命令被信号打死：返回 **128 + 信号号**（如 SIGTERM → 143）。
  ⚠️ 这是相对上游 moreutils 的**有意偏离**（上游返回 1），本实现更贴近 shell 惯例。
- stdout 与 stderr **分流回放**：各归各的流，不会被混成一股。

## iSH 注意事项

- **选项只在命令之前解析**：`chronic -v cmd` 有效；`chronic cmd -v` 会把 `-v` 当参数传给 `cmd`。
- 暂存走 `TMPDIR`（默认 `/tmp`）；匿名暂存文件用完即删（`mkstemp` + `unlink`），进程退出不留垃圾。
- 回放前屏蔽 `SIGPIPE`：下游提前退出时以 `EPIPE` 收手，不会炸成 141。
- **iSH 的 busybox `timeout` 击杀码是 143，不是 GNU 的 124**——判断"是否超时"看 143 或输出，别死认 124。
- 真机实测：`chronic timeout 3s tini -s -- …` 能干净地在 3 秒终止（修复前的 tini 会永远挂住）。

## 相关工具

- `tini` —— 需要信号转发 / 收尸时用它（chronic 只管输出与退出码）
- `sponge` —— 想把管道结果落盘（先读全再写回）时用它
- `faketty` —— 需要 PTY/终端语义时用它，不是用来降噪的
