# sponge —— 先把 stdin 全读完再写文件

moreutils 0.70 的 sponge。解决"读和写同一个文件"的经典问题——`sort f > f` 会先截断 f 导致结果为空，`sort f | sponge f` 安全。任何"管道结果覆盖原文件"的场合都该用它。

## 推荐用法

```sh
# 1) 就地排序：先吞完 stdin，再写回同一文件
printf 'c\na\nb\n' > f2
sort f2 | sponge f2
cat f2                       # a  b  c

# 2) 就地删空行
printf 'a\n\nb\n\n' > notes.txt
grep -v '^$' notes.txt | sponge notes.txt
cat notes.txt                # a  b

# 3) 追加模式 -a：不覆盖，接在文件尾部
printf 'new line\n' | sponge -a log.txt

# 4) 先建好目录，再往里面写（目录不存在会报错）
mkdir -p out && printf 'x\n' | sponge out/result.txt
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `<file>` | 目标文件（位置参数，写最后） |
| `-a` | 追加到文件尾（默认覆盖） |

## 退出码 / 错误处理

- `0` = 成功
- `1` = 输出文件打不开：`error opening output file: No such file or directory`
- 实测：**不给文件参数时不报错**，把 stdin 原样透传到 stdout（行为像 `cat`）；脚本里务必写清文件名

## iSH 注意事项

- `sponge --help` 不是 GNU 风格：报 `unrecognized option: -` 并打一行用法、退出码 0——别把它当帮助文本解析。
- 陷阱：**输入为空时会把目标文件写成空**。比如 `grep 没匹配到 | sponge 原文件` 会直接清空原文件（实测 `wc -c` 为 0），用前先确认管道一定有输出。
- 与 `sd -i` 的区别：sponge 不解析内容、纯搬运，适合任意"过滤器 + 原文件"组合。
- 无已知平台坑（全静态二进制）。

## 相关工具

- `sd` —— 就地正则替换（自带 `-i`，不需要管道）
- `patch` —— 按补丁文件精确改动
- `chronic` —— 需要"成功静默、失败回放"的包装时用它
