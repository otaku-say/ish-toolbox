# zip —— Info-ZIP zip 3.0（全静态单文件）

> 一行定位：创建 PKZIP 兼容的 .zip 压缩包（Windows/macOS 原生可打开；`-r` 递归、`-u` 更新、`-d` 删除）。

## 推荐用法（可原样复制）

```sh
Z=/path/to/tools/zip/arm64/zip    # iSH/arm64；amd64 换 amd64 目录

# 打包（原样复制）
"$Z" out.zip file1.txt file2.txt
"$Z" -r out.zip dir/               # 递归打包目录
"$Z" -9 out.zip big.bin            # 最大压缩
"$Z" out.zip -x "*.tmp"            # 排除模式

# 更新（文件新增/修改后重新入包）
"$Z" -u out.zip changed.txt

# 从包里删除条目
"$Z" -d out.zip obsolete.txt

# 查看/校验途径：
#   - 工具箱已提供 unzip（tools/unzip）：完整校验用 "$U" -t out.zip
#   - 或 python3：python3 -m zipfile -l out.zip
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-r` | 递归目录 |
| `-u` | 更新（只入更新的文件） |
| `-d` | 从压缩包删除条目 |
| `-9` / `-0` | 最大压缩 / 不压缩 |
| `-x PATTERN` | 排除匹配的文件 |
| `-j` | 丢弃路径（只留文件名） |
| `-q` / `-v` | 安静 / 详细 |
| `-T` | 测试包完整性（需要 PATH 里有 `unzip`） |

## 退出码

- `0` 成功；`12` 无文件可打包；其它非 0 为错误（细节 `zip -h2` 有完整表）

## iSH 注意事项

- 全静态 aarch64/amd64 单文件，零依赖；体积约 0.10 / 0.11（UPX 后）
- 本构建：deflate/store 全功能；**bzip2 支持未编译**（默认不影响常规使用）
- `zip -T` 依赖 PATH 中的 `unzip`（iSH/busybox 自带 unzip 即可用）
- 与 macOS `zip`、Windows 资源管理器互认（PKZIP 3.0 格式）
- 中文文件名：按 UTF-8 字节存储（Info-ZIP 传统行为）；跨平台阅读如需规范 Unicode，优先用 `tar`/`7z` 类工具

## 相关工具

- `tar` —— Unix 世界打包/压缩标准工具
- `xz` —— 更高压缩比（.xz）
- `zstd` —— 快速压缩（工具箱另有）
