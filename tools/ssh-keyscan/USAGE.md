# ssh-keyscan —— 批量采集主机公钥（OpenSSH 10.5p1）

从服务器抓 host key、写 known_hosts（免首次连接交互）。只读、无副作用。输出默认带注释行；**不会自动写文件**，且信任前先核对指纹。

## 推荐用法

```sh
# 采 github.com 全部类型（-T 10 = 协议超时 10 秒；外层再套 timeout 兜底）
timeout 25 ssh-keyscan -T 10 github.com

# 去注释只留 key（-q）、限定类型、从文件读主机列表（-f - 可读 stdin）
printf 'github.com\n' > /tmp/ks_demo/hosts.txt
timeout 25 ssh-keyscan -q -T 10 -t ed25519 -f /tmp/ks_demo/hosts.txt

# 追加进 known_hosts 并核对指纹（先核对，再信任）
timeout 25 ssh-keyscan -q -T 10 -t ed25519 github.com >> /tmp/ks_demo/kh
ssh-keygen -lF github.com -f /tmp/ks_demo/kh

# 非 22 端口：输出前缀为 [主机]:端口
timeout 25 ssh-keyscan -q -p 443 -T 10 -t ed25519 ssh.github.com

# 负例：不可达地址 = 无输出 + rc=1（实测 192.0.2.1）
timeout 15 ssh-keyscan -T 3 192.0.2.1; echo "rc=$?"
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-T <秒>` | 每主机超时（实测；仍建议外层再包 timeout） |
| `-t <类型>` | 指定 key 类型（rsa / ecdsa / ed25519 …；默认采样全部） |
| `-p <端口>` | 端口（非 22 时输出带 `[host]:port` 前缀，实测） |
| `-q` | 安静：只输出 key 行、去掉注释行（实测） |
| `-H` | 输出的主机名做哈希（`|1|…`，可直接进 known_hosts，实测） |
| `-f <文件\|->` | 主机列表文件；`-` = stdin（两种来源均实测） |
| `-4` | 强制 IPv4（实测） |
| `-c` | 采集主机证书；普通服务器无证书（实测 github：仅注释行 + rc=1） |

## 退出码

- `0` = 至少采到一把 key（实测）
- `1` = 无任何结果（不可达实测；`-c` 无证书实测）
- `143` = 被 `timeout` 击杀（iSH 语义）

## iSH 注意事项

- 一定要外层套 `timeout`：`-T` 只覆盖协议读取，遇到奇怪网络仍可能拖长。
- 主机不可达时静默 + rc=1（无 stderr 提示，实测 192.0.2.1）——脚本要靠 rc 判断。
- 采集结果需手动 `>> known_hosts`；生产环境先 `ssh-keygen -lF` 核对指纹再信任。
- 主机公钥 ≠ TLS 证书：HTTPS 证书检查用 `openssl s_client`，两者不要混淆。
- DNS 读 `/etc/resolv.conf`（iOS 托管，别改）；解析异常先换 IP 或用 `-4`。
- 想一步到位也可用 `ssh -o StrictHostKeyChecking=accept-new`（连接时自动写 known_hosts）。

## 相关工具

- `ssh-keygen` —— `-F/-R/-H/-lF` 管理 known_hosts
- `ssh` —— known_hosts 的消费者
- `scp` / `sftp` —— 共用同一 known_hosts
- `openssl` —— TLS 证书检查（与主机公钥是两码事）
