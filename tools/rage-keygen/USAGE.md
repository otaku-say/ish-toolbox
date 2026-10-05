# rage-keygen —— rage 密钥生成（age-format identity/keypair）

生成 age 格式的密钥对：**身份文件**（含私钥，`AGE-SECRET-KEY-1...`）+ **公钥**（`age1...`）。
与 `age-keygen` 输出格式完全一致，可混用。

## 推荐用法

```sh
# 1) 生成密钥对 → 文件（推荐：身份文件权限自动 600 风格，注意保护）
rage-keygen -o key.txt
#   文件内容形如：
#   # created: 2026-10-06...
#   # public key: age1xxxx...
#   AGE-SECRET-KEY-1XXXX...

# 2) 只看公钥（把公钥给加密方）
grep 'public key' key.txt

# 3) 直接输出到 stdout（不落盘时）
rage-keygen

# 4) 身份文件 → 收件人列表（-y：把 key.txt 转成只含公钥的列表）
rage-keygen -y -o key.pub.txt key.txt

# 5) 版本
rage-keygen --version      # rage-keygen 0.12.1
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-o FILE` | 输出文件（缺省 stdout） |
| `-y` | 转换模式：身份文件 → 收件人列表（输入 `[INPUT]` 给身份文件） |
| `-h` / `--help` | 帮助 |
| `-V` / `--version` | 版本 |

## 退出码 / 错误处理

- 0 成功；非 0 失败（无权限写文件 / 输入格式错误等）。
- **私钥只存在于身份文件**：请立刻备份并限制权限（`chmod 600`）；泄露即需换对重加密。

## iSH 注意事项

- 按键生于系统 CSPRNG，无需额外配置；iSH 真机实测生成+加解密回环通过（2026-10）。
- 身份文件是纯文本（age 格式），跨平台可移植；不要贴进聊天/仓库。

## 相关工具

- `rage` —— 用生成的密钥加密/解密
- `ssh-keygen` —— SSH 密钥（rage 也直接支持 SSH 密钥，可不用本工具）
