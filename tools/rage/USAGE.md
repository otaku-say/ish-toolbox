# rage —— 现代文件加密（age 格式；Rust 实现）

age 加密格式的另一实现（`str4d/rage`，Rust）：与 age **完全互操作**（文件/密钥格式一致），
官方分发 musl 静态二进制。用途：文件/管道加密、密钥对管理、SSH 密钥直接当收件人。

（本套件原 `age` 已由 `rage` 替代——格式互通，本实现为单文件静态且持续维护。）

## 推荐用法

```sh
# 1) 生成密钥对（身份文件含私钥，注意保管）
rage-keygen -o key.txt

# 2) 加密：给公钥收件人；-a 输出 PEM 文本（便于粘贴/邮件）
rage -r age1xxxx... -a -o secret.txt.age secret.txt

# 3) 解密
rage -d -i key.txt -o secret.txt secret.txt.age

# 4) 口令加密（不依赖密钥文件；解密时交互输入口令）
rage -p -o backup.tar.age backup.tar

# 5) 管道加密
tar czf - mydir | rage -r age1xxxx... -o mydir.tgz.age

# 6) SSH 公钥当收件人（解密时用对应 SSH 私钥做身份）
rage -R ~/.ssh/id_ed25519.pub -o s.age s
rage -d -i ~/.ssh/id_ed25519 -o s s.age

# 7) 版本 / 帮助
rage --version        # rage 0.12.1
rage --help
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-e`（默认） | 加密 |
| `-d` | 解密 |
| `-p` | 口令模式（加密/解密） |
| `-r RECIPIENT` | 收件人公钥（可重复） |
| `-R PATH` | 收件人列表文件（每行一个，`#` 注释） |
| `-i IDENTITY` | 身份文件（解密；可重复，也支持 SSH 私钥） |
| `-a` | ASCII armor：输出 PEM 文本 |
| `-o OUTPUT` | 输出文件（缺省 stdout；**已存在会被覆盖**） |
| `--max-work-factor` | 口令解密允许的最大工作因子（防 DoS） |

## 退出码 / 错误处理

- 0 成功；非 0 失败（解密失败/格式错误/收件人不匹配）。
- 输出缺省走 stdout，`-o` 覆盖已存在文件——脚本里注意保护现场。

## iSH 注意事项

- 官方 musl 静态资产（static-pie）：iSH 真机实测 `--version` 与 加解密全回环通过
  （`rage-keygen` → `-r` 加密 → `-d -i` 解密 → diff 一致，2026-10）。
- 数据流式处理，内存占用与文件大小无强相关。
- 交互口令（`-p` 解密）需要 TTY；脚本场景优先 `-i` 身份文件。

## 相关工具

- `rage-keygen` —— 配套密钥生成（本套件内含）
- `ssh-keygen` —— SSH 密钥；rage 可直接拿 SSH 密钥当收件人/身份
- `faketty` —— 需要给交互提示塞伪终端时用
