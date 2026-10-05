# zstd —— zstandard 压缩/解压（单文件，管道友好）

Zstandard CLI v1.5.7（全静态 aarch64）。压缩率明显好于 gzip、速度接近。单文件压缩/解压/完整性校验都行；多文件先 tar 再 zstd。管道场景用 `-c`。

## 推荐用法

```sh
# 1) 压缩：默认生成 f.txt.zst 并保留原文件（-k 是默认行为）
printf 'hello\n' > f.txt
zstd f.txt && ls                    # f.txt  f.txt.zst

# 2) 解压：-d；原 .zst 默认也保留
rm f.txt && zstd -d f.txt.zst && cat f.txt

# 3) 管道：-c 走 stdout，-q 压掉统计输出
printf 'data' | zstd -q -c | zstd -d -q -c; echo

# 4) 高压缩等级（1-19，越大越慢）
zstd -19 -q -f -o small.zst big.txt

# 5) 校验压缩包完整性
zstd -t f.txt.zst                   # f.txt.zst : 11 bytes

# 6) 压完删源文件
zstd -q --rm data.bin               # data.bin 消失，留 data.bin.zst
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-d` | 解压 |
| `-o FILE` | 指定输出文件（压缩/解压都可） |
| `-c` | 写 stdout（管道用），保留输入文件 |
| `--rm` | 成功后删除输入文件 |
| `-1`…`-19` | 压缩等级，默认 3 |
| `-q` | 压掉统计/警告输出 |
| `-f` | 强制：覆盖已有输出、允许特殊输入输出 |
| `-t` | 测试压缩文件完整性 |
| `-T#` | 线程数（`0` = 全部核心） |

## 退出码 / 错误处理

- `0` = 成功
- `1` = 出错，如文件不存在：`zstd: can't stat /x.zst : No such file or directory -- ignored`

## iSH 注意事项

- 统计输出走 **stderr**（`in.txt :218.18% ( 11 B => 24 B, in.txt.zst)`）；重定向 stdout 时不会混进数据，不想要就 `-q`。
- 实测压缩和解压**默认都保留输入文件**；要省空间自己加 `--rm`。
- 小文件压完反而更大（实测 11 B → 24 B），是头部开销，正常。
- `-T0` 在本机意义有限（单核环境），不必特意多线程。
- 与 busybox 的 `gzip` 格式互不兼容：自己压的包统一用 zstd 解。

## 相关工具

- `tar` —— 目录/多文件：`tar cf - dir | zstd -q -o dir.tar.zst`
- `age` —— 敏感数据先加密（或先压后加）
- `gzip`（busybox）—— 只认 gzip 格式的场景
