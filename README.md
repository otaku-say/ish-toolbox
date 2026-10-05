# ish-toolbox

免依赖（静态链接）CLI 工具集，**arm64 + amd64 双架构**，随上游 Release 自动更新。

用途：给 **iSH（Alpine Linux，aarch64，musl）** 和 **云端沙箱（x86_64）** 提供同一套零依赖的现代命令行工具——两边命令名、版本、行为完全一致。

## 特点

- **单文件零依赖**：静态链接，拷到任何目录都能跑，不依赖 glibc/musl 的 `.so`
- **双架构**：`tools/arm64/`（iSH 用）+ `tools/amd64/`（沙箱 / 桌面 Linux 用）
- **自动跟随上游**：CI 每天从各上游的 latest Release 抓取、校验、覆盖
- **校验严格**：入库前过三重判定，任何一项不过就不入库（见下）

## 工具清单

| 命令 | 替代 | 用途 | 上游 |
|---|---|---|---|
| `bat` | cat | 语法高亮看源码；`bat -l diff` 兼做 diff 渲染 | sharkdp/bat |
| `rg` | grep | 高速递归搜索，尊重 .gitignore | BurntSushi/ripgrep |
| `fd` | find | 按模式找文件 | sharkdp/fd |
| `fzf` | — | 模糊选择列表 / 历史 / 文件 | junegunn/fzf |
| `sd` | sed | 正则替换，免转义斜杠 | chmln/sd |
| `xh` | curl | HTTPie 风格 HTTP 客户端 | ducaale/xh |
| `zoxide` | cd | 按访问频次智能跳转目录 | ajeetdsouza/zoxide |
| `dust` | du | 树状显示目录占用 | bootandy/dust |
| `ouch` | tar / unzip | 统一解压，自动识别格式 | ouch-org/ouch |
| `gping` | ping | 延迟折线图，多目标对比 | orf/gping |
| `age` | gpg | 文件加密，支持直接用 SSH 密钥 | FiloSottile/age |
| `kibi` | nano | Rust 写的极简编辑器（**0.2MB**） | ilai-deutel/kibi |
| `bottom` | top / ps | 终端 TUI 监控 | ClementTsang/bottom |
| `riff` | — | diff 着色 | walles/riff |

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
