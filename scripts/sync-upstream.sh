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
bat|sharkdp/bat|语法高亮看源码，兼做 diff 渲染
rg|BurntSushi/ripgrep|高速递归搜索
fd|sharkdp/fd|按模式找文件
fzf|junegunn/fzf|模糊选择列表
sd|chmln/sd|正则替换
curl|stunnel/static-curl|HTTP 客户端（静态构建，含 TLS/HTTP2/HTTP3/压缩；替代体积更大的 xh）
zoxide|ajeetdsouza/zoxide|目录智能跳转
dust|bootandy/dust|目录占用树
ouch|ouch-org/ouch|统一解压
gping|orf/gping|ping 延迟折线图
age|FiloSottile/age|文件加密
kibi|ilai-deutel/kibi|极简终端编辑器
bottom|ClementTsang/bottom|终端 TUI 监控
'

arch_of() { case "$(uname -m)" in aarch64|arm64) echo arm64 ;; x86_64|amd64) echo amd64 ;; *) echo unknown ;; esac; }
# TARGET_ARCH 供 CI 架构矩阵覆盖：x86_64 runner 上也能产出 arm64 产物
# （下载上游 arm64 资产 + readelf 判定，不需要真机执行）
want_arch="${TARGET_ARCH:-$(arch_of)}"
case "$want_arch" in arm64) A_RE='aarch64|arm64'; A_EM=b7 ;; amd64) A_RE='x86_64|amd64'; A_EM=3e ;; *) echo "✗ 不支持的架构"; exit 1 ;; esac
mkdir -p "$T/arm64" "$T/amd64"

fail=0; ok=0

# 用文件重定向而非管道喂 while：管道会在子 shell 里执行，计数变量传不回来
printf '%s\n' "$LIST" > "$W/list"
while IFS='|' read -r cmd repo desc; do
  [ -z "${cmd:-}" ] && continue
  curl -fsSL --max-time 30 ${AUTH:+-H "$AUTH"} -o "$W/m.json" \
    "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null || {
    echo "  ✗ $cmd 上游不可达"; fail=$((fail+1)); continue; }
  tag=$(jq -r '.tag_name // empty' "$W/m.json" 2>/dev/null)
  [ -z "$tag" ] && { echo "  ✗ $cmd 无 latest"; continue; }

  # 选资产：linux + 目标架构 + 归档格式，排除其它操作系统
  url=$(jq -r --arg re "$A_RE" '
    [ .assets[]?
      | select(.name | test($re))
      | select(.name | test("linux|musl"; "i"))
      | select(.name | test("\\.(tar\\.gz|tgz|tar\\.xz|zip)$"))
      | select(.name | test("openbsd|freebsd|windows|darwin|android|msvc|apple"; "i") | not)
      | select(.name | test("-dev|glibc"; "i") | not)   # 排除 dev 变体与 glibc 版（static-curl 有这些）
    ] | sort_by((if (.name|test("musl";"i")) then 0 else 1 end), .size)
    | .[0].browser_download_url // empty' "$W/m.json" 2>/dev/null)

  if [ -z "$url" ]; then   # 裸二进制资产（如 riff）
    url=$(jq -r --arg re "$A_RE" '
      [ .assets[]? | select(.name|test($re)) | select(.name|test("linux";"i"))
        | select(.name|test("openbsd|freebsd|windows|darwin|android";"i")|not)
        | select(.name|test("\\.(tar\\.gz|tgz|zip)$")|not) ]
      | .[0].browser_download_url // empty' "$W/m.json" 2>/dev/null)
  fi
  [ -z "$url" ] && { echo "  ✗ $cmd 无 $want_arch 产物（$tag）"; continue; }

  curl -fsSL --max-time 240 -o "$W/p" "$url" 2>/dev/null || { echo "  ✗ $cmd 下载失败"; continue; }
  rm -rf "$W/x"; mkdir -p "$W/x"
  case "$url" in
    *.zip)    unzip -qo "$W/p" -d "$W/x" 2>/dev/null ;;
    *.tar.xz) tar xJf "$W/p" -C "$W/x" 2>/dev/null ;;
    *.tar.gz|*.tgz) tar xzf "$W/p" -C "$W/x" 2>/dev/null ;;
    *)        cp "$W/p" "$W/x/$cmd" ;;
  esac

  B=$(find "$W/x" -type f -name "$cmd" ! -name '*.md' 2>/dev/null | head -1)
  [ -z "$B" ] && B=$(find "$W/x" -type f -perm -u+x -size +100k 2>/dev/null | head -1)
  [ -f "$B" ] || { echo "  ✗ $cmd 包内找不到主二进制"; continue; }
  chmod +x "$B"

  readelf -l "$B" 2>/dev/null | grep -q INTERP && { echo "  ✗ $cmd 非静态（有 PT_INTERP）"; continue; }
  readelf -d "$B" 2>/dev/null | grep -q NEEDED  && { echo "  ✗ $cmd 非静态（有 NEEDED）"; continue; }
  em=$(od -An -tx1 -j18 -N1 "$B" 2>/dev/null | tr -d ' \n')
  [ "$em" = "$A_EM" ] || { echo "  ✗ $cmd 架构不符（e_machine=$em，期望 $A_EM）"; continue; }

  cp "$B" "$T/$want_arch/$cmd" && chmod +x "$T/$want_arch/$cmd"
  printf '  ✓ %-8s %-12s %6s MB\n' "$cmd" "$tag" \
    "$(awk -v s=$(wc -c < "$T/$want_arch/$cmd") 'BEGIN{printf "%.1f", s/1048576}')"
  # 必须用 tab 分隔——gen-table.sh 按 tab 读；写成竖线会让整行被当成第一列（踩过）
  printf '%s\t%s\t%s\t%s\n' "$cmd" "$repo" "$tag" "$desc" >> "$W/manifest.part"
  ok=$((ok+1))
done

if [ -s "$W/manifest.part" ]; then
  { printf 'tool\trepo\tversion\tdescription\n'; sort "$W/manifest.part"; } > "$ROOT/MANIFEST.tsv"
fi
for a in arm64 amd64; do
  ( cd "$T/$a" && sha256sum * > SHA256SUMS 2>/dev/null )
done

echo "完成：$want_arch 更新 $ok 个"
[ "$ok" -eq 0 ] && exit 1
exit 0