# xz —— XZ Utils 5.8.4（全静态单文件）

> 一行定位：.xz/.lzma 格式压缩与解压（高压缩比、支持多线程）；busybox 的 xz 只能解压——本工具**压缩+解压都行**。

## 推荐用法（可原样复制）

```sh
X=/path/to/tools/xz/arm64/xz     # iSH/arm64；amd64 换 amd64 目录

# 压缩（-k 保留源文件、-9 最高级别、-T0 用满 CPU 核）
"$X" -k -9 -T0 data.bin            # 生成 data.bin.xz

# 解压
"$X" -dc data.bin.xz > out.bin     # 解压到 stdout
"$X" -dk data.bin.xz               # 落地解压且保留 .xz

# 校验 / 查看信息
"$X" -t data.bin.xz                # 完整性测试（无输出即 OK，rc=0）
"$X" -l data.bin.xz                # 列表：压缩前后大小与比率

# 软链名分发：unxz / xzcat / lzma / unlzma / lzcat 都是一个文件
ln -sf "$X" "$HOME/bin/lzcat"
lzcat data.bin.xz | head           # 等价于 xz -dc
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-d` / `-z` | 解压 / 压缩（默认压缩） |
| `-k` | 保留输入文件 |
| `-c` | 输出到 stdout |
| `-0`…`-9` | 压缩级别（-9 最高，默认 -6） |
| `-e` | 更极限的压缩（慢） |
| `-T0` | 多线程（0=自动核数） |
| `-l` / `-t` | 列表 / 完整性测试 |
| `-q` / `-v` | 安静 / 详细 |
| `-f` | 覆盖已存在输出 |

## 退出码

- `0` 成功；`1` 错误；`2` 警告（例如用了 `-k` 类提示性场景）

## iSH 注意事项

- 全静态 aarch64/amd64 单文件，零依赖；体积约 0.12 / 0.12（UPX 后）
- 与系统/busybox xz 的区别：**busybox 只能解压**，本工具压缩/解压/测试/列表全功能
- 多线程 `-T0` 在 iSH 上可用（取决于内核线程数与文件大小）
- 典型搭配：`tar cJf` 压缩 tar.xz 时需要 PATH 里有 `xz`（把本工具软链为 `xz` 放进 PATH，或直接 `xz -dc` 后接 tar）

## 相关工具

- `tar` —— 打包（`-J` 走外部 xz；`-z` 走 gzip）
- `zip` —— PKZIP 格式（Windows/macOS 兼容）
- `zstd` —— 更快的现代压缩（工具箱另有）
