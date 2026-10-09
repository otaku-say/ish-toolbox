# ish-toolbox

免依赖（静态链接）CLI 工具集，**arm64 + amd64 双架构**，随上游 Release 自动更新。

用途：给 **iSH（Alpine Linux，aarch64，musl）** 和 **云端沙箱（x86_64）** 提供同一套零依赖的现代命令行工具——两边命令名、版本、行为完全一致。

## 特点

- **单文件零依赖**：静态链接，拷到任何目录都能跑，不依赖 glibc/musl 的 `.so`（`python3`/`uv` 为自解压壳：外壳静态，首次运行解压到 /tmp，之后零开销；Alpine/iSH 直达，glibc 系需自备 musl loader）
- **双架构 · 一工具一目录**：每个命令在 `tools/<tool>/<arch>/<tool>`（工具目录内含 `arm64/` 与 `amd64/`）；架构清单 `tools/SHA256SUMS.arm64` / `tools/SHA256SUMS.amd64`
- **自动跟随上游**：CI 每天从各上游的 latest Release 抓取、校验、覆盖
- **校验严格**：入库前过三重判定，任何一项不过就不入库（见下）

## 工具清单

<!-- 下表由 scripts/gen-table.sh 自动生成（上游版本 / 仓库版本 / 双架构体积） -->

<!-- TABLE:START -->
| 工具 | 用途 | 上游最新 | 仓库版本 | arm64 | amd64 | 状态 |
|---|---|---|---|---|---|---|
| `bash` | Bash 5.3 全静态（readline 内建） |  | 5.3 | 0.6 MB | 0.6 MB | ✅ 源码构建 |
| `busybox` | 瑞士军刀（自编译，上游只发源码，全静态单文件） |  | 1.38.0 | 0.7 MB | 0.6 MB | ✅ 源码构建 |
| `chronic` | 命令成功则静默、失败才回放输出（对齐 moreutils：-v 分段标签 / -e stderr 触发=2 / 流分离；含 TMPDIR/EINTR/SIGPIPE 加固） |  | 1.3 | 0.0 MB | 0.0 MB | ✅ 源码构建 |
| `coreutils` | GNU 核心工具集官方多路复用单文件（100+ 命令；argv[0]/--coreutils-prog 分发；自编译静态） |  | 9.12 | 0.7 MB | 0.7 MB | ✅ 源码构建 |
| `csvquote` | CSV 逗号/换行保护（配合 awk/cut 双通管道） | v0.1.5 | 0.1.5 | 0.0 MB | 0.0 MB | ✅ 最新 |
| `curl` | 静态 curl（LibreSSL 后端，内嵌 CA；原生无 TLS1.3 问题，自编译） |  | 8.22.0 | 1.5 MB | 1.5 MB | ✅ 源码构建 |
| `diff` | GNU diff（自编译静态） |  | 3.12 | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `diffstat` | diff 统计（Dickey 原版，自编译） |  | 1.69 | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `entr` | 文件变化时执行命令（视 inode） |  | 5.9 | 0.0 MB | 0.1 MB | ✅ 源码构建 |
| `envsubst` | 环境变量替换（gettext 1.0 首选/0.26 备选；--disable-libasprintf + -all-static） |  | 1.0 | 0.2 MB | 0.2 MB | ✅ 源码构建 |
| `faketty` | 把命令挂进伪终端（PTY）：静态进程也能行缓冲/彩显（替代 stdbuf；输出同终端语义含 \r\n；含 iSH 退出挂死修复补丁） | 1.0.20 | 1.0.20 | 0.2 MB | 0.2 MB | ✅ 最新 |
| `fd` | 按模式找文件 | v10.5.0 | v10.5.0 | 1.1 MB | 1.2 MB | ✅ 最新 |
| `find` | GNU find（-printf/-regex 等完整特性；自编译静态） |  | 4.11.0 | 0.2 MB | 0.1 MB | ✅ 源码构建 |
| `fzy` | 模糊查找器（-e 非交互模式对 Agent 友好） | v1.1 | 1.1 | 0.0 MB | 0.0 MB | ✅ 最新 |
| `gawk` | GNU Awk 5.4.1 全静态（含 --csv 模式） |  | 5.4.1 | 0.3 MB | 0.3 MB | ✅ 源码构建 |
| `grep` | GNU grep（PCRE2 -P 静态链入；自编译静态） |  | 3.12 | 0.2 MB | 0.2 MB | ✅ 源码构建 |
| `head-tail` | 长日志折叠：头 30 + 尾 30 行（60 行内原样；省 Context Token） |  | 1.0 | 0.0 MB | 0.0 MB | ✅ 源码构建 |
| `html2text` | HTML → 纯文本（C++；zig 工具链自编译） | v2.3.0 | 2.3.0 | 0.4 MB | 0.7 MB | ✅ 最新 |
| `hxselect` | 按 CSS 选择器提取 HTML/XML 元素（替代 cascadia） |  | 8.8 | 0.0 MB | 0.1 MB | ✅ 源码构建 |
| `jaq` | jq 的快速 Rust 实现（自编译静态；v3：模块系统 + 大整数无损，速度 2-6×） | v3.1.1 | 3.1.1 | 0.9 MB | 0.9 MB | ✅ 最新 |
| `jo` | 从命令行参数生成 JSON（自编译静态；tag 无 v 前缀） | 1.9 | 1.9 | 0.0 MB | 0.0 MB | ✅ 最新 |
| `lowdown` | Markdown → HTML/终端/roff（bmake 构建） | VERSION_3_2_1 | 3.2.1 | 0.1 MB | 0.1 MB | ✅ 最新 |
| `openssl` | openssl 命令行（LibreSSL 自建：s_client/证书/摘要全套） |  | 4.3.3 | 1.0 MB | 1.0 MB | ✅ 源码构建 |
| `patch` | 打补丁（自编译，上游无 arm64 musl 产物） |  | default | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `pstree` | 进程树（ncurses 静态链，只交付 pstree） |  | 23.7 | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `pv` | 管道流量监视器（进度/速率/ETA） | v1.7.24 | 1.7.24 | 0.1 MB | 0.1 MB | ✅ 最新 |
| `python3` | 动态 musl CPython 自解压壳单文件（LibreSSL 内嵌 CA / sqlite3 / ctypes / lzma / bz2 / uuid / multiprocessing / 内嵌 tzdata；与 uv 兼容；约 5.3MB 起） |  | 3.12.15 | 5.3 MB | 5.4 MB | ✅ 源码构建 |
| `qjs` | QuickJS JavaScript 引擎（qjs 命令行） | v0.17.0 | v0.17.0 | 1.0 MB | 1.0 MB | ✅ 最新 |
| `rage` | 现代文件加密（age 格式兼容；Rust 实现、官发 musl 静态资产） | v0.12.1 | v0.12.1 | 1.2 MB | 1.4 MB | ✅ 最新 |
| `rage-keygen` | rage 密钥生成（age-format identity/keypair） | v0.12.1 | v0.12.1 | 0.9 MB | 1.0 MB | ✅ 最新 |
| `rg` | 高速递归搜索 | 15.2.0 | 15.2.0 | 1.5 MB | 1.8 MB | ✅ 最新 |
| `scp` | SSH 通道文件拷贝（自编译；现代 scp 走 SFTP 协议） |  | 10.5p1 | 0.2 MB | 0.1 MB | ✅ 源码构建 |
| `sd` | 正则替换 | v1.1.0 | v1.1.0 | 0.7 MB | 0.8 MB | ✅ 最新 |
| `sed` | GNU sed（自编译静态） |  | 4.10 | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `sftp` | 交互式 SFTP 文件传输（自编译） |  | 10.5p1 | 0.2 MB | 0.1 MB | ✅ 源码构建 |
| `socat` | 双向数据中继（TCP/UNIX/TLS/管道/PTY；全静态 LibreSSL 后端） |  | 1.8.1.3 | 0.9 MB | 0.9 MB | ✅ 源码构建 |
| `sponge` | 管道落盘：先吞完 stdin 再写文件（避免读-写同文件竞态） |  | 0.70 | 0.0 MB | 0.0 MB | ✅ 源码构建 |
| `sqlite3` | SQLite 命令行（官方只对 x64 发预编译，amalgamation 自编译） |  | default | 0.6 MB | 0.5 MB | ✅ 源码构建 |
| `ssh` | SSH 客户端（全静态；LibreSSL 后端，自编译） |  | 10.5p1 | 0.9 MB | 0.9 MB | ✅ 源码构建 |
| `ssh-add` | 向 ssh-agent 添加密钥（自编译） |  | 10.5p1 | 0.7 MB | 0.7 MB | ✅ 源码构建 |
| `ssh-agent` | SSH 密钥代理（免重复输入口令，自编译） |  | 10.5p1 | 0.7 MB | 0.7 MB | ✅ 源码构建 |
| `ssh-keygen` | SSH 密钥生成/管理（自编译） |  | 10.5p1 | 0.8 MB | 0.7 MB | ✅ 源码构建 |
| `ssh-keyscan` | 批量采集 SSH 主机公钥（自编译） |  | 10.5p1 | 0.8 MB | 0.8 MB | ✅ 源码构建 |
| `strip-ansi` | 过滤 ANSI 转义序列（CSI/OSC/DCS/字符集；UTF-8 安全字节级状态机） |  | 1.0 | 0.0 MB | 0.0 MB | ✅ 源码构建 |
| `su-exec` | 以指定用户身份执行命令（容器/脚本里的权限降级） | v0.3 | v0.3 | 0.0 MB | 0.0 MB | ✅ 最新 |
| `tar` | GNU tar（自编译静态） |  | 1.35 | 0.4 MB | 0.3 MB | ✅ 源码构建 |
| `tini` | 迷你 init：转发信号 + subreaper 收割僵尸进程（守候/后台进程场景；含 iSH 信号修复补丁） | v0.19.0 | v0.19.0 | 0.0 MB | 0.0 MB | ✅ 最新 |
| `tmux` | 终端复用器（全静态；含 iSH SCM_RIGHTS 兜底补丁） | 3.8 | 3.7c | 0.5 MB | 0.5 MB | ⬆ 待同步 |
| `tree` | 目录树展示（自编译，上游无任何二进制） |  | default | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `unzip` | Info-ZIP unzip（自编译静态；30 项安全补丁；支持 -P 加密包 / -t / -Z） |  | 6.0 | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `uv` | 官方 uv（musl 静态）自解压壳单文件（uv venv / pip / tool run 全功能；与 python3 配对；免解压税） | 0.12.24 | 0.12.24 | 9.3 MB | 11.9 MB | ✅ 最新 |
| `xargs` | GNU xargs（-P/-I/--delimiter 完整版；自编译静态） |  | 4.11.0 | 0.1 MB | 0.0 MB | ✅ 源码构建 |
| `xxhsum` | xxHash 校验和 CLI（自编译静态） | v0.8.4 | 0.8.4 | 0.0 MB | 0.0 MB | ✅ 最新 |
| `xz` | Tukaani XZ Utils（xz；unxz/xzcat/lzma 软链名可用；自编译静态） | v5.8.4 | 5.8.4 | 0.1 MB | 0.1 MB | ✅ 最新 |
| `yq` | YAML/JSON 处理（yq-go；自动跟随上游最新版） | v4.54.1 | v4.54.1 | — | 4.9 MB | ✅ 最新 |
| `zip` | Info-ZIP zip（自编译静态） |  | 3.0 | 0.1 MB | 0.1 MB | ✅ 源码构建 |
| `zstd` | zstd 压缩/解压 CLI（自编译静态，支持 -T 多线程） | v1.5.7 | 1.5.7 | 0.3 MB | 0.2 MB | ✅ 最新 |

共 57 个工具 · arm64 合计 36.7 MB · amd64 合计 45.1 MB
<!-- TABLE:END -->

## 每个工具自带使用说明（给 Agent 看）

`tools/<工具>/USAGE.md` 是该工具的使用说明：一行定位 / 推荐用法（可原样复制的命令）/ 常用参数表 /
退出码 / **iSH 平台注意事项** / 相关工具替代关系。清单在 `tools/DOCS.sha256`，
由 `.github/workflows/docs.yml` 维护——**工具目录缺 USAGE.md 即判失败**。

二进制与说明**同源、同版本分发**：本地技能 `install.sh --update` 同时对齐
`tools/SHA256SUMS.<arch>`（二进制）与 `tools/DOCS.sha256`（说明），
所以 `tools/<工具>/<arch>/<工具>` 旁边永远有一份与之匹配的 `USAGE.md`。

## 安装

```sh
git clone https://github.com/otaku-say/ish-toolbox.git
cd ish-toolbox
sh scripts/install.sh                  # 装到 ~/.local/bin（无需 root）
sh scripts/install.sh /usr/local/bin   # 或装到系统目录
```

装完直接敲命令名即可（`install.sh` 会提示是否需要把目录加进 `PATH`）。

## 将 BusyBox 设为系统默认终端（可选）

```sh
sh scripts/install.sh --set-default-busybox          # 安装并设为默认终端
sh scripts/install.sh --unset-default-busybox        # 还原系统原版 / 移除 applet 链接
```

- 兼容 arm64/amd64 与主流发行版，双模式自动判定：
  - **busybox 系**（Alpine、iSH 等：存在 `/etc/alpine-release`，或 `/bin/sh` 指向 busybox）：备份系统原版为 `/bin/busybox.pre-toolbox` 后替换 `/bin/busybox`，`/bin/sh` 与全部 applet 即刻使用工具箱版本；
  - **其他发行版**（Debian、Ubuntu、CentOS、Fedora、Arch、OpenWrt 等）：在 `/usr/local/bin` 建立全部 applet 软链（`--busybox-links-dir=DIR` 可换目录），已存在的同名文件不覆盖。
- 系统已自带 busybox 时（`/bin`、`/usr/bin`、`/sbin`、`/usr/sbin` 任一位置），先备份为 `<路径>.pre-toolbox` 再原地替换为工具箱静态版；不调用包管理器、随时可还原。
- 设为默认终端后，`sh`、`ls` 等命令即工具箱版本；Agent 应主动使用该默认终端（详见 `tools/busybox/USAGE.md`）。

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
