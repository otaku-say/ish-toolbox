# ish-toolbox

免依赖（静态链接）CLI 工具集，**arm64 + amd64 双架构**，随上游 Release 自动更新。

用途：给 **iSH（Alpine Linux，aarch64，musl）** 和 **云端沙箱（x86_64）** 提供同一套零依赖的现代命令行工具——两边命令名、版本、行为完全一致。

## 特点

- **单文件零依赖**：静态链接，拷到任何目录都能跑，不依赖 glibc/musl 的 `.so`
- **双架构 · 一工具一目录**：每个命令在 `tools/<tool>/<arch>/<tool>`（工具目录内含 `arm64/` 与 `amd64/`）；架构清单 `tools/SHA256SUMS.arm64` / `tools/SHA256SUMS.amd64`
- **自动跟随上游**：CI 每天从各上游的 latest Release 抓取、校验、覆盖
- **校验严格**：入库前过三重判定，任何一项不过就不入库（见下）

## 工具清单

<!-- 下表由 scripts/gen-table.sh 自动生成（上游版本 / 仓库版本 / 双架构体积） -->

<!-- TABLE:START -->
| 工具 | 用途 | 上游最新 | 仓库版本 | arm64 | amd64 | 状态 |
|---|---|---|---|---|---|---|
| `age` | 现代文件加密（X25519/SSH 密钥；age + age-keygen） | v1.3.2 | v1.3.2 | 3.5 MB | 3.8 MB | ✅ 最新 |
| `age-keygen` | age 密钥生成（age-format identity/keypair） | v1.3.2 | v1.3.2 | 2.1 MB | 2.3 MB | ✅ 最新 |
| `cascadia` | HTML CSS 选择器提取（stdin/stdout 管道） | v1.5.1 | v1.5.1 | 2.3 MB | 2.5 MB | ✅ 最新 |
| `curl` | 静态 curl（LibreSSL 后端，内嵌 CA；原生无 TLS1.3 问题，自编译） |  | 8.22.0 | 1.5 MB | 1.5 MB | ✅ 源码构建 |
| `doggo` | DNS 查询（dig 现代替代，多协议） | v1.4.0 | v1.4.0 | 4.3 MB | 4.9 MB | ✅ 最新 |
| `fd` | 按模式找文件 | v10.5.0 | v10.5.0 | 1.1 MB | 1.2 MB | ✅ 最新 |
| `file` | file(1) magic 识别文件类型（配套 magic.mgc 同目录，wrapper 自动指 MAGIC） |  | 5.48 | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `jaq` | jq 的快速 Rust 实现（自编译静态；v3：模块系统 + 大整数无损，速度 2-6×） | v3.1.1 | 3.1.1 | 0.9 MB | 0.9 MB | ✅ 最新 |
| `micropython` | MicroPython 解释器（unix port，静态自编译） | v1.29.0 | default | 0.6 MB | 0.7 MB | ✅ 源码构建 |
| `mlr` | CSV/TSV/JSON 数据切片（Miller） | v6.22.0 | v6.22.0 | 4.3 MB | 5.1 MB | ✅ 最新 |
| `openssl` | openssl 命令行（LibreSSL 自建：s_client/证书/摘要全套） |  | 4.3.3 | 0.9 MB | 0.8 MB | ✅ 源码构建 |
| `patch` | 打补丁（自编译，上游无 arm64 musl 产物） |  | default | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `qjs` | QuickJS JavaScript 引擎（qjs 命令行） | v0.17.0 | v0.17.0 | 1.0 MB | 1.0 MB | ✅ 最新 |
| `rg` | 高速递归搜索 | 15.2.0 | 15.2.0 | 1.5 MB | 1.8 MB | ✅ 最新 |
| `scp` | SSH 通道文件拷贝（自编译；现代 scp 走 SFTP 协议） |  | 10.5p1 | 0.2 MB | 0.1 MB | ✅ 源码构建 |
| `sd` | 正则替换 | v1.1.0 | v1.1.0 | 0.7 MB | 0.8 MB | ✅ 最新 |
| `sftp` | 交互式 SFTP 文件传输（自编译） |  | 10.5p1 | 0.2 MB | 0.1 MB | ✅ 源码构建 |
| `socat` | 双向数据中继（TCP/UNIX/TLS/管道/PTY；全静态 LibreSSL 后端） |  | 1.8.1.3 | 0.8 MB | 0.8 MB | ✅ 源码构建 |
| `sponge` | 管道落盘：先吞完 stdin 再写文件（避免读-写同文件竞态） |  | 0.70 | 0.0 MB | 0.0 MB | ✅ 源码构建 |
| `sqlite3` | SQLite 命令行（官方只对 x64 发预编译，amalgamation 自编译） |  | default | 0.5 MB | 0.5 MB | ✅ 源码构建 |
| `ssh` | SSH 客户端（全静态；LibreSSL 后端，自编译） |  | 10.5p1 | 0.9 MB | 0.9 MB | ✅ 源码构建 |
| `ssh-add` | 向 ssh-agent 添加密钥（自编译） |  | 10.5p1 | 0.7 MB | 0.7 MB | ✅ 源码构建 |
| `ssh-agent` | SSH 密钥代理（免重复输入口令，自编译） |  | 10.5p1 | 0.7 MB | 0.7 MB | ✅ 源码构建 |
| `ssh-keygen` | SSH 密钥生成/管理（自编译） |  | 10.5p1 | 0.8 MB | 0.7 MB | ✅ 源码构建 |
| `ssh-keyscan` | 批量采集 SSH 主机公钥（自编译） |  | 10.5p1 | 0.8 MB | 0.8 MB | ✅ 源码构建 |
| `stdbuf` | LD_PRELOAD 调整子进程缓冲（-i/-o/-e；配套 libstdbuf.so 同目录） |  | 1.0 | 0.0 MB | 0.0 MB | ✅ 源码构建 |
| `su-exec` | 以指定用户身份执行命令（容器/脚本里的权限降级） | v0.3 | v0.3 | 0.0 MB | 0.0 MB | ✅ 最新 |
| `tree` | 目录树展示（自编译，上游无任何二进制） |  | default | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `zstd` | zstd 压缩/解压 CLI（自编译静态，支持 -T 多线程） | v1.5.7 | 1.5.7 | 0.3 MB | 0.2 MB | ✅ 最新 |

共 29 个工具 · arm64 合计 41.1 MB · amd64 合计 43.7 MB
<!-- TABLE:END -->

## 安装

```sh
git clone https://github.com/otaku-say/ish-toolbox.git
cd ish-toolbox
sh scripts/install.sh                  # 装到 ~/.local/bin（无需 root）
sh scripts/install.sh /usr/local/bin   # 或装到系统目录
```

装完直接敲命令名即可（`install.sh` 会提示是否需要把目录加进 `PATH`）。

## 体检

```sh
sh scripts/doctor.sh            # 体检本机架构
sh scripts/doctor.sh arm64      # 体检 arm64 产物
```

三项判定全过才算健康：

1. **完整性** —— 比 `SHA256SUMS`
2. **免依赖** —— 无 `PT_INTERP`（动态加载器）+ 无 `NEEDED`（共享库）
3. **架构正确** —— 读 ELF 头第 18 字节 `e_machine`（`b7`=aarch64，`3e`=x86_64），**不信文件名**

## 自动更新

`.github/workflows/sync.yml` 每天 UTC 03:23 自动运行：

```
上游 latest release → 按架构选资产（musl 优先，排除 openbsd/freebsd/windows/darwin）
                    → 下载 → 三重判定 → 覆盖 → 更新 MANIFEST/SHA256SUMS
                    → 有变更才 commit（版本没变则无空提交）
```

架构矩阵在同一个 x86_64 runner 上跑两遍：arm64 任务下载并用 `readelf` 判定 arm64 产物（不需要真机执行）。

也可在 Actions 页面手动触发。

## 设计原则（踩坑换来的）

1. **资产名是线索，不是证据。** 大量项目的 `-linux` 资产其实是 glibc 动态版。必须实测 `readelf`。
2. **aarch64-musl 稀缺是系统性的。** 很多 Rust 项目只给 x86_64 配 musl target，aarch64 只出 gnu——那些在 Alpine 上根本跑不起来。
3. **Go 项目（CGO_ENABLED=0）的 arm64 资产通常是静态的**，资产名不带 `musl` 不代表不行——但同样要实测。
4. **平台要过滤。** 同名资产里混着 openbsd/freebsd/windows 版本，`amd64` 正则会误选到 OpenBSD 版。
5. **别信 AI 说的「某某有静态版」。** 核验过一份 AI 生成的推荐，20+ 工具里 6 处硬错。

## 相关

- 技能目录（本仓库的 iSH 侧载体）：`/var/minis/skills/ish-toolbox/`
- 母本与重建脚本：`/var/minis/shared/ish-toolbox/`
