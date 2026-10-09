# unzip —— Info-ZIP Unzip 6.0（全静态单文件；含完整安全补丁）

> 一行定位：解压 PKZIP 兼容的 .zip（支持加密包、Zip64；含 2014–2022 全部历史 CVE 修复与 zipbomb 防护）。

## 推荐用法（可原样复制）

```sh
U=/path/to/tools/unzip/arm64/unzip    # iSH/arm64；amd64 换 amd64 目录

# 解压（常用姿势）
"$U" out.zip                     # 解到当前目录
"$U" -d dir/ out.zip             # 指定目录
"$U" -o out.zip                  # 覆盖（不询问）
"$U" -n out.zip                  # 不覆盖
"$U" -q out.zip                  # 安静模式

# 查看内容（unzip 兼作 zipinfo）
"$U" -l out.zip                  # 列表
"$U" -Z out.zip                  # zipinfo 视图

# 加密包：务必带 -P（不带会尝试交互输入——非 TTY 环境会挂住）
"$U" -P '密码' out.zip

# 完整性校验
"$U" -t out.zip
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-o` / `-n` | 覆盖 / 不覆盖 |
| `-d DIR` | 指定解压目录 |
| `-l` / `-Z` | 列表 / zipinfo 视图 |
| `-P PWD` | 密码（非交互） |
| `-t` | 测试压缩包完整性 |
| `-x PATTERN` | 排除条目 |
| `-C` | 大小写不敏感匹配 |
| `-q` / `-v` | 安静 / 详细 |

## 与 busybox unzip 的差异（实测，2026-10）

| 场景 | busybox unzip | 本工具 |
|---|---|---|
| 普通 deflate 包 | ✓ | ✓ |
| **加密包** | ✗ 直接报 "encryption is not supported" | ✓ `-P 密码` |
| **Zip64** | 解析异常（实测报 "short read"，内容不可信） | ✓ |
| `-t` 完整性校验 / `-Z` zipinfo 视图 | ✗ | ✓ |
| CVE 修复 & zipbomb 防护 | 无 | 2014–2022 全量 |
| 无密码时行为 | 不支持 | 会尝试交互输入（脚本请 `timeout` 包裹） |

## 小贴士

- **GBK 名称乱码**：zip 未标注 UTF-8 时，中文名按原始字节存放。本构建未含旧发行版的
  `-O` 字符集插件（现代 Debian/Alpine 均已移除）；可用 python3 转换名称：

  ```python
  import zipfile
  zf = zipfile.ZipFile("x.zip")
  for i in zf.infolist():
      raw = i.filename.encode("cp437", "replace")   # 还原原始字节
      name = raw.decode("gbk", "replace")           # 按 GBK 解名
      print(name)
  ```

- **bzip2 压缩方法的条目**：本构建未启用（此类包罕见；可用 7z / python 特殊处理）。
- 与工具箱 `zip 3.0` 互认：`zip -T` 完整校验可直接配合本工具。

## 退出码

0 成功；1 一般错误；2 格式问题；9 找不到文件；其余见 `"$U" -h2`

## iSH 注意事项

- 全静态 aarch64/amd64 单文件、零依赖；体积小（百 KB 级）。
