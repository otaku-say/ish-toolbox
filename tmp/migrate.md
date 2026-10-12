## AOJIT 迁移说明（2026-10）

minis 内置 AOJIT 加速后，以下 15 个工具已从本仓库下架，改由 AOJIT 加速的系统版 + apk 提供（实测更快）：

| 下架工具 | 替代（AOJIT 加速） | apk 补全 |
|---|---|---|
| `busybox`（1.38.0） | 系统 `/bin/busybox` 1.37.0-r8（全速） | 已装，无需补 |
| `python3`（3.12.15） | 系统 `/usr/bin/python3` 3.12.15-r0（90% + json/hashlib/socket 等子模块 96-100%） | `apk add py3-pip`（pip）；pillow/numpy 已在镜像 |
| `ssh`/`scp`/`sftp`/`ssh-add`/`ssh-agent`/`ssh-keygen`/`ssh-keyscan`（10.5p1） | 系统 openssh-client 9.9_p2-r0（全速 + libcrypto 握手加速） | 已装 |
| `curl`（8.22.0） | apk curl（动态，链 libcrypto/libssl/zlib/musl 间接受益） | `apk add curl` |
| `openssl`（4.3.3） | apk openssl（libcrypto 93%、libssl 99%） | `apk add openssl` |
| `sqlite3` | apk sqlite（链 sqlite-libs 3.48.0-r4） | `apk add sqlite` |
| `socat` | apk socat（TLS 中继吃 libcrypto） | `apk add socat` |
| `drill` | `apk add bind-tools`（dig/nslookup）或系统 drill（`apk add drill`） | 按需二选一 |
| `uv`（0.12.24） | `apk add uv` 或 `pip install uv`（配系统 python3 用） | 按需 |

注意：

- ssh 为版本回退（10.5p1 → 9.9_p2），拿速度换新特性；curl/openssl 从 LibreSSL 切到 OpenSSL 3.3.2（当年为绕 TLS1.3 后量子问题才自建 LibreSSL，切完需复测握手 / `s_client` / 默认验链）。
- `install.sh` 的 `--set-default-busybox` 已同步移除（系统 busybox 即 AOJIT 全速版，无需替换）。
- 重置后恢复：`apk add curl openssl sqlite py3-pip` + 本仓库 `install.sh`（其余工具）。
