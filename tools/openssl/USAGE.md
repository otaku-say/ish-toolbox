# openssl —— 加解密 / 摘要 / 证书（LibreSSL 4.3.3）

本机是 **LibreSSL** 的 openssl，子命令与 OpenSSL 3.x 有明显差异，不要照抄 OpenSSL 3 文档。常用：rand / dgst / enc / base64 / passwd / s_client / req / x509。

## 推荐用法

```sh
# 1) 随机数与摘要
openssl rand -hex 8                              # 16 个 hex 字符
openssl dgst -sha256 file.txt                    # SHA256(file.txt)= 2cf24dba...
printf 'abc' | openssl dgst -sha256              # (stdin)= ba7816bf...
printf 'data' | openssl dgst -sha1 -hmac secret  # HMAC

# 2) base64 编解码（解码输入末尾必须带换行，或加 -A）
printf 'hello' | openssl base64                  # aGVsbG8=
printf 'aGVsbG8=\n' | openssl base64 -d          # hello

# 3) 对称加密往返（-pbkdf2 走 PBKDF2 派生）
printf 'secret' > p.txt
openssl enc -aes-256-cbc -pbkdf2 -k pass123 -in p.txt -out p.enc
timeout 5 openssl enc -d -aes-256-cbc -pbkdf2 -k pass123 -in p.enc   # secret

# 4) 查远端证书链（</dev/null 防交互挂住，外面再套 timeout）
timeout 15 openssl s_client -connect example.com:443 -servername example.com </dev/null | head -25

# 5) 自签证书（本机缺默认 config，必须自带最小 config）
cat > my.cnf <<'EOF'
[ req ]
distinguished_name = dn
[ dn ]
EOF
timeout 60 openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -subj '/CN=test.local' -config my.cnf -keyout key.pem -out cert.pem
openssl x509 -in cert.pem -noout -subject -dates   # subject= /CN=test.local
```

## 常用参数

| 命令 / 参数 | 作用 |
|---|---|
| `rand -hex N` | N 字节随机数的 hex 串 |
| `dgst -sha256 [-hmac KEY]` | 摘要 / HMAC（文件或 stdin） |
| `enc -aes-256-cbc -pbkdf2 -k PW` | 对称加密；`-d` 解密，`-in/-out` 指定文件 |
| `base64 [-d]` / `enc -base64` | base64 编/解码 |
| `s_client -connect H:443 -servername H` | TLS 连接、看证书链 |
| `req -x509 -newkey rsa:2048 -nodes -days N -subj '/CN=x' -config F` | 自签证书 |
| `x509 -in CERT -noout -subject -dates` | 查看证书字段 |
| `passwd [-1] [-salt S]` | 生成 crypt 口令串（`-1` = MD5 版） |

## 退出码 / 错误处理

- `0` = 成功；`1` = 命令失败（如缺 config 的 `req`、读不到文件）
- 正常操作 stdout 是结果、stderr 只有下面那条 WARNING，不要被吓到

## iSH 注意事项

- **每条命令都会在 stderr 打**：`WARNING: can't open config file: /usr/etc/ssl/openssl.cnf`；rand/dgst/enc 等实测不受影响，想安静用 `2>/dev/null`。
- 需要读 config 的子命令（req 等）必须自带 `-config`（最小配置见上例），否则 `Unable to load config info` 直接失败、不产出文件（实测）。
- base64 解码的坑：**输入最后一行没有换行符时静默输出空**（实测：`printf 'aGVsbG8=' | openssl base64 -d` 无任何输出）；补 `\n` 或用 `-A`（单行模式）。
- `s_client` 连上后等输入：用 `</dev/null`，外层再套 `timeout N` 兜底。
- 参数集与 OpenSSL 3.x 不同；写脚本前先 `openssl help` 或 `openssl <子命令> -help` 核对。

## 相关工具

- `curl` —— HTTP 层请求（证书由内嵌 CA 自动验证）
- `age` —— 文件加密（比手搓 enc 更不容易用错）
- `ssh-keygen` —— SSH 密钥生成
