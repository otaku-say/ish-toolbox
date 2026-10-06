# strip-ansi —— 过滤 ANSI 转义序列，只留纯文本

把带颜色/光标控制/窗口标题的终端输出洗成**干净文本**：CSI（颜色、清屏、光标）、OSC（标题、超链接）、
DCS/SOS/PM/APC 字符串、字符集指令、两字节序列全部摘掉；**其余字节原样透传**（UTF-8 安全）。

用途：日志/命令输出喂给 Agent 或存档前的标准清洗步骤。

## 推荐用法

```sh
# 1) 管道清洗（最常用）
some_cmd | strip-ansi > clean.log

# 2) 洗已有的 raw 日志
strip-ansi < raw.log > clean.log

# 3) 原地覆盖同名文件时，用 sponge 接力（直接 `strip-ansi < f > f` 会先清空 f）
strip-ansi < raw.log | sponge raw.log

# 4) 与 faketty 组合：终端语义的彩色输出 → 纯文本
faketty some_cmd 2>&1 | strip-ansi

# 5) 快速验证：SGR 颜色码是 CSI 的子集
printf '\033[31mred\033[0m\n' | strip-ansi        # 输出 red

# 6) 版本 / 帮助
strip-ansi --version                              # strip-ansi 1.0
strip-ansi --help
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `--version` | 打印版本（rc=0） |
| `-h` / `--help` | 帮助（rc=0） |

无其他参数：纯 stdin→stdout 过滤器（可放在任何管道位置）。

## 处理范围

| 序列 | 形态 | 例子 |
|---|---|---|
| CSI | `ESC [ ...` 终止于 `0x40-0x7E` | `ESC[31m`、`ESC[2J`、`ESC[38;5;196m` |
| OSC | `ESC ] ...` 终止于 `BEL` 或 `ST` | `ESC]0;title BEL`、`ESC]8;;url ST` |
| DCS/SOS/PM/APC | `ESC P/X/^/_ ...` 终止于 `ST` | 少见，一并吞掉 |
| 字符集/中间字节类 | `ESC ( ) * + - . / #` 等 + 终止字节 | `ESC(B`、`ESC#8` |
| 两字节 | `ESC M`、`ESC 7`、`ESC c` 等 | 直接吞 |

## 退出码 / 错误处理

- 正常结束 rc=0；unfinished 序列在 EOF 处直接丢弃（尾随单个 `ESC` 不留脏字符）。
- 管道下游提前退出时以 SIGPIPE 终止，属正常 Unix 语义（`cmd | strip-ansi | head` 不报错）。

## iSH 注意事项

- **字节级状态机**：只认 `ESC(0x1B)` 起始的序列，**不处理 0x9B 单字节 CSI**——因为 0x9B 会和
  UTF-8 续字节（0x80-0xBF）撞车，造成正文误吞。中文/emoji 等 UTF-8 内容零误伤（有 sha 保真测试）。
- 内存 O(1)、流式处理，任意大输入可跑。
- 参考稿中 `ESC(B` 消费字符集字节后**状态未复位**、会多吃一个字符——本实现已修正
  （`x ESC(B y` → 输出 `xy`）。

## 相关工具

- `head-tail` —— 洗完还要折叠长日志时接在它后面
- `faketty` —— 方向相反：把无缓冲输出变行缓冲/带颜色；本工具负责去色
- `sponge` —— 需要"读全再写回原文件"（避免自截断）时用它
