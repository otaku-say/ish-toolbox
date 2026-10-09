#!/bin/sh
# sync-upstream.sh —— 跟随上游自动更新二进制（CI 核心，可本地跑）
#
# 策略：每次运行都从上游 latest release 重新抓取 + 验证 + 覆盖。
# 幂等——版本没变时产物字节一致，git 层面无 diff，CI 不会产生空提交。
# 这样做的好处是逻辑单一、没有"版本号比较"的边界情况（资产改名/撤回都能自愈）。
#
# 判定标准（三重，缺一不可）：
#   1. readelf 无 PT_INTERP（无动态加载器）
#   2. readelf 无 NEEDED（不依赖共享库）
#   3. ELF 头的 e_machine 与目标架构一致（第 18 字节：b7=aarch64, 3e=x86_64）
#
# 依赖：curl jq readelf（ubuntu-latest 自带）
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$ROOT/tools"
AUTH=""; [ -n "${GITHUB_TOKEN:-}" ] && AUTH="Authorization: Bearer ${GITHUB_TOKEN}"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT INT TERM

# cmd | repo | 说明
LIST='
rg|BurntSushi/ripgrep|高速递归搜索
fd|sharkdp/fd|按模式找文件
sd|chmln/sd|正则替换
su-exec|ncopa/su-exec|以指定用户身份执行命令（容器/脚本里的权限降级）
qjs|quickjs-ng/quickjs|QuickJS JavaScript 引擎（qjs 命令行）|^qjs-linux-
rage|str4d/rage|现代文件加密（age 格式兼容；Rust 实现、官发 musl 静态资产）
rage-keygen|str4d/rage|rage 密钥生成（age-format identity/keypair）
'

arch_of() { case "$(uname -m)" in aarch64|arm64) echo arm64 ;; x86_64|amd64) echo amd64 ;; *) echo unknown ;; esac; }
# TARGET_ARCH 供 CI 架构矩阵覆盖：x86_64 runner 上也能产出 arm64 产物
# （下载上游 arm64 资产 + readelf 判定，不需要真机执行）
want_arch="${TARGET_ARCH:-$(arch_of)}"
case "$want_arch" in arm64) A_RE='aarch64|arm64'; A_EM=b7 ;; amd64) A_RE='x86_64|amd64'; A_EM=3e ;; *) echo "✗ 不支持的架构"; exit 1 ;; esac
case "$want_arch" in arm64) other_arch=amd64 ;; amd64) other_arch=arm64 ;; esac
mkdir -p "$T/arm64" "$T/amd64"

fail=0; ok=0

# 用文件重定向而非管道喂 while：管道会在子 shell 里执行，计数变量传不回来
printf '%s\n' "$LIST" > "$W/list"
# 清单第 4 列（可选）= 资产名过滤正则：解决「同一 release 里多个相似资产」的歧义
# （例：quickjs-ng 同时发 qjs-linux-aarch64 和 qjsc-linux-aarch64，按体积排序会选错）
while IFS='|' read -r cmd repo desc flt; do
  [ -z "${cmd:-}" ] && continue
  curl -fsSL --max-time 30 ${AUTH:+-H "$AUTH"} -o "$W/m.json" \
    "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null || {
    echo "  ✗ $cmd 上游不可达"; fail=$((fail+1)); continue; }
  tag=$(jq -r '.tag_name // empty' "$W/m.json" 2>/dev/null)
  [ -z "$tag" ] && { echo "  ✗ $cmd 无 latest"; continue; }

  # 选资产：linux + 目标架构 + 归档格式，排除其它操作系统
  url=$(jq -r --arg re "$A_RE" --arg flt "$flt" '
    [ .assets[]?
      | select(.name | test($re))
      | select(($flt == "") or (.name | test($flt)))
      | select(.name | test("linux|musl"; "i"))
      | select(.name | test("\\.(tar\\.gz|tgz|tar\\.xz|zip|deb)$"))
      | select(.name | test("openbsd|freebsd|windows|darwin|android|msvc|apple"; "i") | not)
      | select(.name | test("-dev|glibc"; "i") | not)   # 排除 dev 变体与 glibc 版（static-curl 有这些）
    ] | sort_by((if (.name|test("musl";"i")) then 0 else 1 end), .size)
    | .[0].browser_download_url // empty' "$W/m.json" 2>/dev/null)

  if [ -z "$url" ]; then   # 裸二进制资产（如 riff、su-exec）
    # 注意：不要求名字含 "linux" —— su-exec 的资产就叫 su-exec-static-v0.3-arm64，
    # 只按「排除其它平台」来判定，否则永远匹配不到
    url=$(jq -r --arg re "$A_RE" --arg flt "$flt" '
      [ .assets[]? | select(.name|test($re))
        | select(($flt == "") or (.name|test($flt)))
        | select(.name|test("openbsd|freebsd|windows|darwin|android|msvc|apple|ppc64|s390x|riscv|armv7";"i")|not)
        | select(.name|test("\\.(tar\\.gz|tgz|zip|tar\\.xz)$")|not)
        | select(.name|test("checksums|sha256";"i")|not) ]
      | .[0].browser_download_url // empty' "$W/m.json" 2>/dev/null)
  fi
  [ -z "$url" ] && { echo "  ✗ $cmd 无 $want_arch 产物（$tag）"; continue; }

  curl -fsSL --max-time 240 -o "$W/p" "$url" 2>/dev/null || { echo "  ✗ $cmd 下载失败"; continue; }
  rm -rf "$W/x"; mkdir -p "$W/x"
  case "$url" in
    *.zip)    unzip -qo "$W/p" -d "$W/x" 2>/dev/null ;;
    *.tar.xz) tar xJf "$W/p" -C "$W/x" 2>/dev/null ;;
    *.tar.gz|*.tgz) tar xzf "$W/p" -C "$W/x" 2>/dev/null ;;
    # .deb 支持：rage 的官方 musl 静态产物以 deb 分发（2026-10）；dpkg-deb 拆包，
    # 无 dpkg-deb 时回退 ar + tar（data.tar 的压缩由 GNU tar 自动探测）
    *.deb)    dpkg-deb -x "$W/p" "$W/x" 2>/dev/null || { (cd "$W/x" && ar x "$W/p" && tar xf data.tar.* 2>/dev/null); } ;;
    *)        cp "$W/p" "$W/x/$cmd" ;;
  esac

  # 主二进制选择：优先认 ELF 魔数（7f 45 4c 46）——deb/tar 里常有与命令同名的
  # 补全脚本/文档（如 rage 的 bash-completion），find 的遍历顺序不定，会抓错
  # （2026-10 实锤：rage 抓到补全脚本 e_machine=6c）。找不到 ELF 才退回旧启发式。
  B=""
  for f in $(find "$W/x" -type f -name "$cmd" ! -name '*.md' 2>/dev/null); do
    if [ "$(od -An -tx1 -N4 "$f" 2>/dev/null | tr -d ' \n')" = "7f454c46" ]; then B="$f"; break; fi
  done
  [ -z "$B" ] && B=$(find "$W/x" -type f -perm -u+x -size +100k 2>/dev/null | head -1)
  [ -f "$B" ] || { echo "  ✗ $cmd 包内找不到主二进制"; continue; }
  chmod +x "$B"

  readelf -l "$B" 2>/dev/null | grep -q INTERP && { echo "  ✗ $cmd 非静态（有 PT_INTERP）"; continue; }
  readelf -d "$B" 2>/dev/null | grep -q NEEDED  && { echo "  ✗ $cmd 非静态（有 NEEDED）"; continue; }
  em=$(od -An -tx1 -j18 -N1 "$B" 2>/dev/null | tr -d ' \n')
  [ "$em" = "$A_EM" ] || { echo "  ✗ $cmd 架构不符（e_machine=$em，期望 $A_EM）"; continue; }

  mkdir -p "$T/$cmd/$want_arch"
  cp "$B" "$T/$cmd/$want_arch/$cmd" && chmod +x "$T/$cmd/$want_arch/$cmd"

  # ── UPX 压缩（能用就用；失败自动回退）────────────────────────
  # 注意：CI 的 runner 是 x86_64，arm64 产物**无法运行验证**，
  # 所以这里只做「UPX 后三判据仍成立」的检查（架构/静态性不被破坏）。
  local_note=""
  if [ "${UPX:-1}" = 1 ] && command -v upx >/dev/null 2>&1; then
    _f="$T/$cmd/$want_arch/$cmd"; _pre=$(wc -c < "$_f"); cp "$_f" "$_f.pre-upx"
    if upx --best -q "$_f" 2>/dev/null; then
      _em2=$(od -An -tx1 -j18 -N1 "$_f" | tr -d ' \n')
      if [ "$_em2" = "$A_EM" ] && ! readelf -d "$_f" 2>/dev/null | grep -q NEEDED; then
        local_note="+UPX $(awk -v a="$_pre" -v c="$(wc -c < "$_f")" 'BEGIN{printf "%d%%", c*100/a}')"
      else
        mv "$_f.pre-upx" "$_f"
      fi
    else
      mv "$_f.pre-upx" "$_f"
    fi
    rm -f "$_f.pre-upx" "$_f.upx"   # $_f.upx 是 UPX 中断时的残缺残留，必须清
  fi

  printf '  ✓ %-8s %-12s %6s MB %s\n' "$cmd" "$tag" \
    "$(awk -v s=$(wc -c < "$T/$cmd/$want_arch/$cmd") 'BEGIN{printf "%.1f", s/1048576}')" "$local_note"
  # 必须用 tab 分隔——gen-table.sh 按 tab 读；写成竖线会让整行被当成第一列（踩过）
  printf '%s\t%s\t%s\t%s\n' "$cmd" "$repo" "$tag" "$desc" >> "$W/manifest.part"
  ok=$((ok+1))
done < "$W/list"

if [ -s "$W/manifest.part" ]; then
  # 合并两个来源：sync 清单（本脚本自动写）+ MANIFEST.extra.tsv（自编译工具，手工维护）
  {
    cat "$W/manifest.part"
    if [ -f "$ROOT/MANIFEST.extra.tsv" ]; then tail -n +2 "$ROOT/MANIFEST.extra.tsv"; fi
  } | sort > "$W/manifest.all"
  { printf 'tool\trepo\tversion\tdescription\n'; cat "$W/manifest.all"; } > "$ROOT/MANIFEST.tsv"
fi

# ── 孤儿清理：删掉「不在清单里」的旧工具与 UPX 残留 ────────────────
# 触发场景：某工具被替换（如 xh → curl）后，旧文件会一直留在仓库里；
# UPX 被中断时也会留下 <file>.upx 残缺文件。
# 自编译的工具不在本清单里，必须显式保留，否则会被误删。
SELF_BUILT="patch tree sqlite3 curl zstd openssl sponge ssh scp sftp ssh-keygen ssh-keyscan ssh-agent ssh-add socat jaq faketty tini chronic drill strip-ansi head-tail jo html2text envsubst diffstat lowdown xxhsum pstree fzy entr csvquote pv hxselect tmux bash gawk python3 busybox uv"
printf '%s\n' "$LIST" | cut -d'|' -f1 > "$W/known"
for k in $SELF_BUILT; do echo "$k" >> "$W/known"; done
# 布局：tools/<tool>/<arch>/<tool>（每工具一枚目录，内含 arm64/amd64 子目录）。
# 清理三件事：①顶层散文件（旧平铺布局残留）②已下架工具的目录 ③旧「按架构分组」的
# tools/<arch>/ 目录（只由对应架构的 job 删除自己那只；内容已迁移到 <tool>/<arch>/）。
for entry in "$T"/*; do
  [ -e "$entry" ] || continue
  _n=$(basename "$entry")
  case "$_n" in
    "SHA256SUMS.$want_arch"|"SHA256SUMS.$other_arch"|DOCS.sha256) continue ;;   # 文档清单同属仓库元数据，不是旧布局残留
  esac
  if [ ! -d "$entry" ]; then
    echo "  - 清理散文件：$_n"; rm -f "$entry"; continue
  fi
  case "$_n" in
    "$want_arch"|"$other_arch")
      if [ "$_n" = "$want_arch" ]; then
        echo "  - 移除旧布局目录：$_n/（已迁移到 <tool>/$want_arch/）"; rm -rf "$entry"
      fi
      continue ;;
  esac
  if grep -qx "$_n" "$W/known"; then
    rm -f "$entry/$want_arch"/*.upx "$entry/$want_arch"/*.pre-upx 2>/dev/null
  else
    echo "  - 清理清单外的目录：$_n"; rm -rf "$entry"
  fi
done
# 只重算本架构的基线（每架构一个清单文件，跨 job 互不写同一文件）；
# 路径含 <tool>/<arch>/ 相对 tools/ 根。
( cd "$T" && find . -path "./*/$want_arch/*" -type f | sed 's|^\./||' | sort | xargs -r sha256sum > "SHA256SUMS.$want_arch" )

echo "完成：$want_arch 更新 $ok 个"
[ "$ok" -eq 0 ] && exit 1
exit 0
