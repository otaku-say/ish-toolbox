# ssh-keygen —— 密钥生成与管理（OpenSSH 10.5p1）

生成/转换密钥、看指纹、运维 known_hosts。Agent 场景：为测试造无密码密钥、核对/清理 known_hosts 主机项。

## 推荐用法

```sh
# 生成无密码 ed25519（脚本必带 -f/-N；不带会弹交互问路径）
mkdir -p /tmp/kg_demo && ssh-keygen -q -t ed25519 -f /tmp/kg_demo/id -N '' -C 'agent@ish'

# 指纹：默认 SHA256；MD5 用 -E；bubblebabble 用 -B
ssh-keygen -lf /tmp/kg_demo/id.pub
ssh-keygen -lE md5 -f /tmp/kg_demo/id.pub

# 从私钥导出公钥（写 authorized_keys 用）
ssh-keygen -y -f /tmp/kg_demo/id

# 改/清密码（-P 旧密码 -N 新密码；'' = 无密码）
ssh-keygen -p -f /tmp/kg_demo/id -N 'pw1' -P ''
ssh-keygen -p -f /tmp/kg_demo/id -N '' -P 'pw1'

# 改注释
ssh-keygen -c -f /tmp/kg_demo/id -C 'new-comment' -P ''
```

```sh
# known_hosts 运维（先生成数据：ssh-keyscan -q github.com >> /tmp/kg_demo/kh）
ssh-keygen -F github.com -f /tmp/kg_demo/kh    # 找到 rc=0；未找到 rc=1
ssh-keygen -lF github.com -f /tmp/kg_demo/kh   # 直接看指纹（信任前核对）
ssh-keygen -R github.com -f /tmp/kg_demo/kh    # 删除（自动留 kh.old 备份）
ssh-keygen -H -f /tmp/kg_demo/kh               # 哈希化主机名（|1|…）
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-q` | 安静模式 |
| `-t ed25519\|rsa\|ecdsa\|mldsa44-ed25519` | 类型；本机含 10.5 的 ML-DSA 后量子类型（实测可生成） |
| `-b <bits>` | 位宽（RSA 2048 / ECDSA 256 实测） |
| `-f <文件>` | 输出文件；脚本必须显式给，否则交互询问（默认 ~/.ssh/id_ed25519） |
| `-N ''` | 空密码（实测生成无密码密钥） |
| `-C <注释>` | 公钥注释列 |
| `-a <轮数>` | KDF 轮数（-a 8 实测） |
| `-y` | 私钥→公钥（实测与 .pub 逐字节一致） |
| `-l` / `-lE md5` / `-lF <主机>` | 指纹 / 指定算法 / known_hosts 按主机查指纹 |
| `-B` | bubblebabble 指纹（实测输出形如 `xebap-suriv-…`） |
| `-e` / `-i` | 公钥导出/导入（配 `-m RFC4716`；实测往返丢注释） |
| `-p` / `-c` | 改密码 / 改注释 |
| `-F` / `-R` / `-H` | known_hosts 查 / 删 / 哈希 |

## 退出码

- `0` 成功
- `1` 常规失败（实测：`-F` 未找到 = 1；参数错误 = 1）
- `143` 被 `timeout` 击杀

## iSH 注意事项

- 没有帮助选项：`ssh-keygen -?`（报错带 usage）才是看用法的方式；实测 `-h` 会直接走进"生成密钥"流程并弹保存路径，别踩。
- 测试密钥一律 `-f /tmp/...` 或 mktemp -d；不要动 `~/.ssh` 里已有密钥。
- 带密码私钥在无终端环境不可交互输入：`-y/-e` 报 `incorrect passphrase supplied`（实测）——脚本用无密码密钥，或 SSH_ASKPASS（未验证）。
- `-e -m PEM` 对 ed25519 报 `unsupported key type ED25519`（实测）；PEM 导出仅 RSA/ECDSA（RSA 实测输出 `-----BEGIN RSA PUBLIC KEY-----`）。
- `-R` / `-H` 改写 known_hosts 会留 `<文件>.old` 备份（实测）。
- `-A` 会往 /etc/ssh 写主机密钥——iSH 上不要跑（未验证）。

## 相关工具

- `ssh-add` —— 把密钥装进 agent
- `ssh` —— `-i` 直接使用密钥
- `ssh-keyscan` —— known_hosts 数据来源
- `age` —— 也支持用 SSH 密钥做加密（用途不同）
