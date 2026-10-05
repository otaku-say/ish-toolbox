# age —— 现代文件加密（收件人公钥 / 身份文件）

age v1.3.2。加密用收件人公钥（`-r age1...`），解密用身份文件（`-d -i`）。文件加密、备份加密、把东西安全放公共位置的场景用它；预先安排好密钥就用它，口令模式（`-p`）在 iSH 上不可用（见下）。

## 推荐用法

```sh
# 准备：生成临时密钥对（-o 写文件，公钥打印到 stderr）
age-keygen -o key.txt
# stderr: Public key: age1rzldfs4e6xu...

# 1) 用收件人公钥加密
printf 'secret data\n' > plain.txt
age -r age1rzldfs4e6xu... -o secret.age plain.txt

# 2) 用身份文件解密
age -d -i key.txt -o out.txt secret.age
cat out.txt

# 3) 装甲文本格式（-a）：PEM 风格，适合贴进聊天/邮件
age -a -r age1... -o secret.asc plain.txt
age -d -i key.txt secret.asc

# 4) 多收件人：文件每行一个公钥，# 开头是注释
age -R recipients.txt -o multi.age data.bin

# 5) 对称用法：把身份文件当对称密钥（-e -i）
age -e -i key.txt -o s.age data
age -d -i key.txt s.age
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-r KEY` | 收件人公钥（可重复），`age1...` 形式 |
| `-R FILE` | 从文件读收件人列表（每行一个，`#` 注释） |
| `-d` | 解密 |
| `-i FILE` | 身份文件（可重复；解密必需；配合 `-e` 可对称加密） |
| `-o FILE` | 输出文件（默认 stdout；**已存在会被覆盖**） |
| `-a` | 装甲输出（PEM 文本格式） |
| `-e` | 显式声明加密（不加也是加密） |
| `-p` | 口令加密（需交互终端，本机不可用） |

## 退出码 / 错误处理

- `0` = 成功
- `1` = 解密失败：`no identity matched any of the recipients`；参数/文件错误同码

## iSH 注意事项

- `-p` 口令模式在非交互环境必失败：`could not read passphrase: standard input is not a terminal, and /dev/tty is not available`。Agent 场景一律用 `-r/-R/-i`。
- 解密默认输出到 **stdout**（可能打屏）；文件场景记得 `-o`。
- `-o` 输出文件已存在会**直接覆盖**，注意别盖掉源文件。
- 私钥文件没有任何口令概念，密钥文件本身就是秘密；不要 `-o` 到公开路径。
- 收件人也可以是 SSH 公钥（`ssh-ed25519 ...`，帮助文档说明；未在本机实测）。

## 相关工具

- `age-keygen` —— 生成密钥对、导出公钥
- `zstd` —— 大文件先压缩再加密
- `openssl` —— 其它加解密/证书场景
