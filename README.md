# ish-toolbox

免依赖（静态链接）CLI 工具集，**arm64 + amd64 双架构**，随上游 Release 自动更新。

用途：给 **iSH（Alpine Linux，aarch64，musl）** 和 **云端沙箱（x86_64）** 提供同一套零依赖的现代命令行工具——两边命令名、版本、行为完全一致。

## 特点

- **单文件零依赖**：静态链接，拷到任何目录都能跑，不依赖 glibc/musl 的 `.so`
- **双架构**：`tools/arm64/`（iSH 用）+ `tools/amd64/`（沙箱 / 桌面 Linux 用）
- **自动跟随上游**：CI 每天从各上游的 latest Release 抓取、校验、覆盖
- **校验严格**：入库前过三重判定，任何一项不过就不入库（见下）

## 工具清单

<!-- 下表由 scripts/gen-table.sh 自动生成（上游版本 / 仓库版本 / 双架构体积） -->

<!-- TABLE:START -->
| 工具 | 用途 | 上游最新 | 仓库版本 | arm64 | amd64 | 状态 |
|---|---|---|---|---|---|---|
| `age` | 文件加密 | v1.3.2 | v1.3.2 | 6.2 MB | 6.7 MB | ✅ 最新 |
| `bat` | 语法高亮看源码，兼做 diff 渲染 | v0.26.1 | v0.26.1 | 5.8 MB | 6.6 MB | ✅ 最新 |
| `bottom` | 终端 TUI 监控 | 0.14.9 | 0.14.9 | 4.1 MB | 5.0 MB | ✅ 最新 |
| `dust` | 目录占用树 | v1.2.6 | v1.2.6 | 2.3 MB | 2.9 MB | ✅ 最新 |
| `fd` | 按模式找文件 | v10.5.0 | v10.5.0 | 2.9 MB | 3.5 MB | ✅ 最新 |
| `fzf` | 模糊选择列表 | v0.74.4 | v0.74.4 | 4.9 MB | 5.3 MB | ✅ 最新 |
| `gping` | ping 延迟折线图 | gping-v1.21.0 | gping-v1.21.0 | 3.3 MB | 3.6 MB | ✅ 最新 |
| `kibi` | 极简终端编辑器 | v0.3.3 | v0.3.3 | 0.2 MB | 0.2 MB | ✅ 最新 |
| `ouch` | 统一解压 | 0.8.3 | 0.8.3 | 5.1 MB | 6.0 MB | ✅ 最新 |
| `rg` | 高速递归搜索 | 15.2.0 | 15.2.0 | 4.3 MB | 5.2 MB | ✅ 最新 |
| `riff` | diff 着色 | 3.6.2 | 3.6.2 | 7.2 MB | 7.0 MB | ✅ 最新 |
| `sd` | 正则替换 | v1.1.0 | v1.1.0 | 1.9 MB | 2.4 MB | ✅ 最新 |
| `zoxide` | 目录智能跳转 | v0.10.0 | v0.10.0 | 1.0 MB | 1.2 MB | ✅ 最新 |
| `curl` | HTTP 客户端（静态构建，含 TLS/HTTP2/3/压缩） | 8.22.0 | 8.22.0 | — | — | ✅ 最新 |

共 14 个工具 · arm64 合计 57.6 MB · amd64 合计 69.8 MB
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
