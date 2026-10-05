# age-keygen —— 生成 age 密钥对 / 导出公钥

age-keygen v1.3.2。生成 X25519（或 `-pq` 后量子混合）密钥对写文件或 stdout；`-y` 从身份文件导出公钥。密钥不含口令，文件本身就是秘密。

## 推荐用法

```sh
# 1) 生成密钥写入文件（推荐）：公钥提示打在 stderr
age-keygen -o key.txt
# stderr: Public key: age1rzldfs4e6xu...

# key.txt 结构（第 2 行注释里才是公钥）：
#   # created: 2026-10-05T20:54:39
#   # public key: age1rzldfs4e6xu...
#   AGE-SECRET-KEY-1NXPUYCMDN80L0...

# 2) 从身份文件导公钥（-y）：发给对方 / 拼进 recipients 文件
age-keygen -y key.txt

# 3) 后量子混合密钥（ML-KEM-768 + X25519；密钥串很长，加解密已实测往返）
age-keygen -pq -o pq.txt

# 4) 不写 -o：私钥打 stdout、公钥打 stderr（脚本里更推荐 -o）
age-keygen > k.txt 2> k.pub
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-o FILE` | 写入文件（**已存在则不覆盖**，退出码 1） |
| `-y` | 读身份文件，输出对应公钥（recipients 格式） |
| `-pq` | 生成后量子混合密钥对 |

## 退出码 / 错误处理

- `0` = 成功
- `1` = 输出文件已存在：`error: failed to open output file "key.txt": file exists`
- 不写 `-o` 时附带警告：`warning: writing secret key to a world-readable file`

## iSH 注意事项

- 公钥藏在文件**第 2 行注释**里：`# public key: age1...`；直接取第 1 行只会拿到 `# created:`。取公钥用 `grep 'public key' key.txt` 或 `age-keygen -y key.txt`。
- `-o` 生成的密钥文件权限实测为 `600`；别 chmod 放宽，更别把内容贴进对话/日志。
- 密钥为单文件、无口令；丢失无法解密，备份 .age 文件时必须连 key.txt 一起备份。
- `-pq` 公钥长约 1959 字符（实测），recipients 文件按单行放即可。

## 相关工具

- `age` —— 用生成的密钥加密/解密
- `ssh-keygen` —— 需要 SSH 密钥（而非 age 密钥）时用它
