# drill —— DNS 查询与 DNSSEC 验证（dig 的替代）

来自 **ldns**（NLnet Labs，1.9.2），全静态 musl + LibreSSL 后端。查 A/AAAA/MX/TXT、反向解析、跟踪委派、
**验证 DNSSEC 签名链**。本份取代已下架的 `doggo`。

## 推荐用法

```sh
# 1) 基本查询：务必显式指定服务器
#    （iSH 默认解析器会先试不可达的 IPv6 DNS，噪音多、慢）
timeout 20 drill example.com @1.1.1.1

# 2) 指定记录类型 / 类别
drill example.com @1.1.1.1 MX
drill example.com @1.1.1.1 AAAA
drill example.com @1.1.1.1 TXT

# 3) 反向解析（IP → 域名）
drill -x 1.1.1.1 @1.1.1.1

# 4) 安静模式：省掉权威/附加段与统计头部（-Q 覆盖 -V）
drill -Q example.com @1.1.1.1

# 5) 要签名记录（置 DO 位）
drill -D example.com @1.1.1.1

# 6) 验证签名链：从域名一路追到已知信任锚（必须自带 -k，见注意事项）
drill -S -k ./root.key example.com @1.1.1.1

# 7) 从根开始跟踪委派（排查 DNS 配置问题）
drill -T example.com @1.1.1.1

# 8) 版本 / 帮助
drill -v      # drill ... version 1.9.2 (ldns version 1.9.2)
drill -h
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `name [@server] [type] [class]` | 位置参数可任意顺序；type 默认 A，class 默认 IN |
| `-4` / `-6` | 只用 IPv4 / 只用 IPv6 |
| `-u` / `-t` | UDP（默认）/ TCP 查询 |
| `-p <port>` | 指定远端端口 |
| `-b <size>` | 缓冲区大小（默认 512） |
| `-a` | 被截断时回退 EDNS0 + TCP |
| `-Q` | 安静模式 |
| `-V <0-5>` | 详细程度 |
| `-x` | 反向解析（IP → 域名） |
| `-D` | 置 DO 位（请求 DNSSEC 记录） |
| `-S` | 从域名追到已知密钥，验证签名链（隐含 DNSSEC） |
| `-T` | 从根向下跟踪委派 |
| `-k <file>` | 信任锚/密钥文件，可多次（`-S`/`-TD` 时用） |
| `-s` | 显示每个密钥的 DS 记录 |
| `-r <file>` | 跟踪时用指定的根提示文件 |
| `-d <domain>` | 跟踪时的起始域 |
| `-y <name:key[:algo]>` | TSIG 密钥 |
| `-f/-i/-w/-q <file>` | 从文件读包 / 打印包 / 写应答 / 写查询包 |

## 退出码 / 错误处理

- `drill -v`、`drill -h` 退出码 0（实测）。
- ⚠️ **查询结果不影响退出码**：实测域名不存在（头部 `rcode: NXDOMAIN`）也是 **rc=0**。
  **脚本里别用退出码判查询成败**，改成 grep 输出：
  - 有答案 → 含 `;; ANSWER SECTION:`
  - 域名不存在 → 头部 `rcode: NXDOMAIN`
- ⚠️ **服务器不可达时会一直等下去**（实测 `@192.0.2.1` 挂到被超时杀掉）。
  **一律用 `timeout N drill …` 包住**。
- `-S` 验证成功输出含 `Chase successful`；追不到是 `Chase failed.`。

## iSH 注意事项

- 全静态 aarch64，**但仍读 `/etc/resolv.conf`**（musl 静态二进制的正常行为）；该文件由 iOS 托管，别去改它。
- **一定要显式 `@服务器`**：`drill example.com`（不写）在 iSH 上会先试不可达的 IPv6 DNS，慢且噪音大。
- `-S` 不给 `-k` 时，默认去读 `/usr/etc/unbound/root.key`；iSH 上**没有这个文件**，要验证签名链就自己带 `-k`。
- `-h` 会先打印版权声明再给用法，属正常。
- 构建注记（复现用）：`--with-ssl` 指向 LibreSSL 静态库；因 LibreSSL 4.3.3 不导出 `SSL_get0_dane`，
  configure 需加 `--disable-dane-ta-usage`（**只关 DANE-TA usage 型支持，DNSSEC 与 DANE 主体不受影响**）。

## 相关工具

- `curl` —— HTTP/TLS 侧；网络排查先 drill 确认解析，再 curl
- `openssl` —— `openssl s_client -connect host:443 -servername host` 看证书链
- `ssh-keyscan` —— 顺带采集主机公钥
