#!/bin/sh
# install.sh —— 把工具箱装到 PATH 里（按当前架构自动选）
#
# 用法：
#   sh install.sh                          # 装到 ~/.local/bin（默认，无需 root）
#   sh install.sh /usr/local/bin           # 装到指定目录（需要权限）
#   sh install.sh --set-default-busybox    # 把工具箱 BusyBox 装为系统默认终端
#   sh install.sh --unset-default-busybox  # 还原系统原版 BusyBox / 移除 applet 链接
#   sh install.sh --busybox-links-dir=DIR  # links 步的目标目录（绝对路径，默认 /usr/local/bin）
#
# 选项可组合，例如：sh install.sh /usr/local/bin --set-default-busybox
# 装完即可直接敲命令名。卸载：删掉目标目录下的同名文件即可。
#
# BusyBox 默认终端（兼容 arm64/amd64 与主流发行版）：
#   · 目标：尽可能把工具箱静态 BusyBox 变成“默认终端”。不调用包管理器、不删除
#     任何系统文件——发现系统自带的 busybox（/bin、/usr/bin、/sbin、/usr/sbin 任一
#     位置）时仅做“备份 + 原地替换”，原版保存为 <路径>.pre-toolbox，可随时用
#     --unset 完整还原；不替换也可正常使用（仅在 links 步生效）。
#   · busybox 系（Alpine/iSH 等：存在 /etc/alpine-release，或 /bin/sh 指向 busybox）：
#     替换后 /bin/sh 与全部 applet 即刻使用工具箱版本，无需额外步骤。
#   · 其他发行版（Debian/Ubuntu/CentOS/Fedora/Arch/OpenWrt 等）：另在目标目录
#     （默认 /usr/local/bin）建立全部 applet 软链；已存在同名文件不覆盖（计入“冲突”）。
#   · 测试/特殊环境可用环境变量 ISH_TOOLBOX_BUSYBOX_MODE=replace|links 强制模式。
set -u

usage() {
  printf '用法：sh %s [目标目录] [选项]\n\n' "$0"
  printf '  （无选项）                 校验并安装当前架构二进制到目标目录（默认 ~/.local/bin）\n'
  printf '  --set-default-busybox      把工具箱 BusyBox 装为系统默认终端：\n'
  printf '                             系统已自带 busybox 时先备份（<路径>.pre-toolbox）再原地替换；\n'
  printf '                             busybox 系（Alpine/iSH）替换 /bin/busybox 即全面生效；\n'
  printf '                             其他发行版另在目标目录（默认 /usr/local/bin）建立 applet 软链\n'
  printf '  --unset-default-busybox    还原系统原版 busybox（从备份恢复）/ 移除 applet 软链\n'
  printf '  --busybox-links-dir=DIR    links 步目标目录，须为绝对路径（默认 /usr/local/bin）\n'
  printf '  --help                     显示本帮助\n'
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SET_DEFAULT_BUSYBOX=0
UNSET_DEFAULT_BUSYBOX=0
BUSYBOX_LINKS_DIR=""
DEST=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --set-default-busybox) SET_DEFAULT_BUSYBOX=1 ;;
    --unset-default-busybox) UNSET_DEFAULT_BUSYBOX=1 ;;
    --busybox-links-dir=*) BUSYBOX_LINKS_DIR="${1#--busybox-links-dir=}" ;;
    --help|-h) usage; exit 0 ;;
    --*) printf '✗ 未知参数：%s（--help 查看用法）\n' "$1" >&2; exit 1 ;;
    *) [ -z "$DEST" ] || { printf '✗ 目标目录只能指定一次\n' >&2; exit 1; }; DEST="$1" ;;
  esac
  shift
done
if [ "$SET_DEFAULT_BUSYBOX" -eq 1 ] && [ "$UNSET_DEFAULT_BUSYBOX" -eq 1 ]; then
  printf '✗ 不能同时使用 --set-default-busybox 与 --unset-default-busybox\n' >&2; exit 1
fi
if [ -n "$BUSYBOX_LINKS_DIR" ]; then
  case "$BUSYBOX_LINKS_DIR" in /*) ;; *) printf '✗ --busybox-links-dir 必须是绝对路径\n' >&2; exit 1 ;; esac
fi

case "$(uname -m)" in
  aarch64|arm64) ARCH=arm64; EM=b7 ;;
  x86_64|amd64)  ARCH=amd64; EM=3e ;;
  *) printf '✗ 不支持的架构：%s\n' "$(uname -m)" >&2; exit 1 ;;
esac
SRC="$ROOT/tools"
BIN_SRC="$SRC/busybox/$ARCH/busybox"
SYS_BB_CANDIDATES="/bin/busybox /usr/bin/busybox /sbin/busybox /usr/sbin/busybox"

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v busybox >/dev/null 2>&1; then
    busybox sha256sum "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    printf '✗ 校验需要 sha256sum、BusyBox 或 openssl\n' >&2; return 1
  fi
}

default_busybox_mode() {
  case "${ISH_TOOLBOX_BUSYBOX_MODE:-}" in
    replace|links) printf '%s\n' "$ISH_TOOLBOX_BUSYBOX_MODE"; return 0 ;;
    '') ;;
    *) printf '✗ ISH_TOOLBOX_BUSYBOX_MODE 仅支持 replace|links\n' >&2; return 1 ;;
  esac
  if [ -f /etc/alpine-release ] \
    || { [ -L /bin/sh ] && { [ "$(readlink /bin/sh)" = "/bin/busybox" ] || [ "$(readlink /bin/sh)" = "busybox" ]; }; }; then
    printf 'replace\n'
  else
    printf 'links\n'
  fi
}

# 替换系统自带 busybox（发现即处理）：备份 + 原地替换 + 自检 + 失败回滚。
# 返回：0 成功（含“未发现/已是我们版本”）；1 出错。
# 统计写入全局：SYS_BB_FOUND / SYS_BB_REPLACED
SYS_BB_FOUND=0
SYS_BB_REPLACED=0
replace_system_busybox() {
  BIN_SHA="$(hash_file "$BIN_SRC")" || return 1
  SYS_BB_FOUND=0
  SYS_BB_REPLACED=0
  SEEN=""
  for f in $SYS_BB_CANDIDATES; do
    [ -e "$f" ] || continue
    if [ -L "$f" ] && [ ! -e "$f" ]; then printf '  跳过失效符号链接：%s\n' "$f"; continue; fi
    r="$(readlink -f "$f" 2>/dev/null || true)"
    if [ -z "$r" ]; then r="$f"; fi
    if [ -L "$f" ]; then printf '  符号链接 %s -> %s\n' "$f" "$r"; fi
    case " $SEEN " in *" $r "*) continue ;; esac
    SEEN="$SEEN $r"
    [ -f "$r" ] || continue
    desc="$("$r" 2>&1 | head -n 1 || true)"
    case "$desc" in
      *BusyBox*|*busybox*) ;;
      *) printf '  跳过非 busybox 文件：%s\n' "$r"; continue ;;
    esac
    SYS_BB_FOUND=$((SYS_BB_FOUND + 1))
    if [ "$(hash_file "$r")" = "$BIN_SHA" ]; then
      printf '  已是工具箱版本：%s\n' "$r"
      continue
    fi
    BAK="$r.pre-toolbox"
    if [ -f "$BAK" ] && [ ! -L "$BAK" ]; then
      if [ "$(hash_file "$BAK")" = "$BIN_SHA" ]; then
        cp "$r" "$BAK" && chmod 755 "$BAK" \
          && printf '  备份内容为工具箱版本，已重新备份系统原版：%s\n' "$BAK"
      fi
    else
      cp "$r" "$BAK" || { printf '✗ 无法备份系统 busybox（需要 root 权限）：%s\n' "$BAK" >&2; return 1; }
      chmod 755 "$BAK"
      printf '  系统原版已备份：%s\n' "$BAK"
    fi
    cp "$BIN_SRC" "$r" || { printf '✗ 无法替换（需要 root 权限）：%s\n' "$r" >&2; return 1; }
    chmod 755 "$r"
    command -v restorecon >/dev/null 2>&1 && restorecon "$r" 2>/dev/null
    if ! "$r" sh -c 'exit 0' >/dev/null 2>&1; then
      cp "$BAK" "$r" >/dev/null 2>&1 || printf '警告：回滚失败，请手动恢复：cp %s %s\n' "$BAK" "$r" >&2
      chmod 755 "$r" 2>/dev/null || :
      printf '✗ 替换后自检失败，已尝试回滚：%s\n' "$r" >&2
      return 1
    fi
    printf '  ✓ 已替换系统自带 busybox：%s\n' "$r"
    SYS_BB_REPLACED=$((SYS_BB_REPLACED + 1))
  done
  if [ "$SYS_BB_FOUND" -eq 0 ]; then
    printf '  未发现系统自带 busybox（跳过替换步骤）\n'
  fi
  return 0
}

set_default_busybox() {
  [ -f "$BIN_SRC" ] && [ -x "$BIN_SRC" ] || { printf '✗ 工具箱缺少 %s 版 busybox：%s\n' "$ARCH" "$BIN_SRC" >&2; return 1; }
  "$BIN_SRC" sh -c 'exit 0' >/dev/null 2>&1 || { printf '✗ 工具箱 busybox 无法在本机运行（架构或内核不兼容）：%s\n' "$BIN_SRC" >&2; return 1; }
  BB_DESC="$("$BIN_SRC" 2>/dev/null | head -n 1)"
  [ -n "$BB_DESC" ] || BB_DESC="工具箱 busybox"

  mode="$(default_busybox_mode)" || return 1

  printf '→ 替换系统自带 busybox（如有；备份后缀 .pre-toolbox）\n'
  replace_system_busybox || return 1

  if [ "$mode" = replace ]; then
    [ -f /bin/busybox ] || { printf '✗ busybox 系系统却未找到 /bin/busybox，异常\n' >&2; return 1; }
    if [ "$(hash_file /bin/busybox)" != "$(hash_file "$BIN_SRC")" ]; then
      printf '✗ /bin/busybox 不是工具箱版本，替换未完成\n' >&2; return 1
    fi
    printf '✓ 默认 busybox 已切换为工具箱版本（busybox 系：/bin/sh 与全部 applet 即刻生效）\n'
    printf '  版本：%s\n' "$BB_DESC"
    printf '  系统原版备份：/bin/busybox.pre-toolbox\n'
    printf '  还原：sh %s --unset-default-busybox\n' "$0"
    return 0
  fi

  # links 步：非 busybox 系，在目标目录建立 applet 软链（让交互 shell 默认用到工具箱版本）
  LINKS_DIR="${BUSYBOX_LINKS_DIR:-/usr/local/bin}"
  if [ ! -d "$LINKS_DIR" ]; then
    mkdir -p "$LINKS_DIR" || { printf '✗ 无法创建目录：%s（需要 root 权限）\n' "$LINKS_DIR" >&2; return 1; }
  fi
  [ -w "$LINKS_DIR" ] || { printf '✗ 目录不可写：%s（用 root/sudo 运行，或用 --busybox-links-dir 指定）\n' "$LINKS_DIR" >&2; return 1; }
  APPLETS="$(mktemp "${TMPDIR:-/tmp}/ish-toolbox-applets.XXXXXX")" || return 1
  "$BIN_SRC" --list > "$APPLETS" 2>/dev/null || { printf '✗ 无法获取 busybox applet 列表\n' >&2; rm -f "$APPLETS"; return 1; }
  created=0; updated=0; skipped=0; conflicts=0; conflict_list=""
  while IFS= read -r applet || [ -n "$applet" ]; do
    [ -n "$applet" ] || continue
    [ "$applet" = busybox ] && continue
    dest="$LINKS_DIR/$applet"
    if [ -L "$dest" ]; then
      target="$(readlink "$dest")"
      if [ "$target" = "$BIN_SRC" ]; then
        skipped=$((skipped + 1)); continue
      fi
      case "$target" in
        */busybox/"$ARCH"/busybox) ln -sfn "$BIN_SRC" "$dest" || { rm -f "$APPLETS"; printf '✗ 无法更新链接：%s\n' "$dest" >&2; return 1; }
                                   updated=$((updated + 1)); continue ;;
      esac
      conflicts=$((conflicts + 1)); conflict_list="$conflict_list $applet"; continue
    fi
    if [ -e "$dest" ]; then
      conflicts=$((conflicts + 1)); conflict_list="$conflict_list $applet"; continue
    fi
    ln -s "$BIN_SRC" "$dest" || { rm -f "$APPLETS"; printf '✗ 无法创建链接：%s\n' "$dest" >&2; return 1; }
    created=$((created + 1))
  done < "$APPLETS"
  rm -f "$APPLETS"
  printf '✓ 工具箱 busybox 已就位（links 步完成）\n'
  printf '  版本：%s\n' "$BB_DESC"
  printf '  链接目录：%s（新建 %s / 更新 %s / 跳过 %s / 冲突 %s）\n' "$LINKS_DIR" "$created" "$updated" "$skipped" "$conflicts"
  if [ "$conflicts" -gt 0 ]; then
    printf '  冲突 applet（保留原文件）：%s\n' "$(printf '%s' "$conflict_list" | cut -c1-160)"
  fi
  printf '  还原：sh %s --unset-default-busybox%s\n' "$0" "${BUSYBOX_LINKS_DIR:+ --busybox-links-dir=$BUSYBOX_LINKS_DIR}"
}

unset_default_busybox() {
  handled=0
  for f in $SYS_BB_CANDIDATES; do
    BAK="$f.pre-toolbox"
    [ -f "$BAK" ] || continue
    [ -L "$BAK" ] && continue
    "$BAK" sh -c 'exit 0' >/dev/null 2>&1 || { printf '✗ 备份文件无法运行，拒绝还原：%s\n' "$BAK" >&2; return 1; }
    # 幂等护栏：当前已是系统原版（与备份一致）时不重复写入
    if [ -f "$f" ] && [ "$(hash_file "$f")" = "$(hash_file "$BAK")" ]; then
      printf '  %s 当前已是系统原版（与备份一致），无需还原\n' "$f"
      handled=1
      continue
    fi
    cp "$BAK" "$f" || { printf '✗ 无法还原（需要 root 权限）：%s\n' "$f" >&2; return 1; }
    chmod 755 "$f"
    command -v restorecon >/dev/null 2>&1 && restorecon "$f" 2>/dev/null
    handled=1
    printf '已还原系统原版 busybox：%s（来源：%s）\n' "$f" "$BAK"
  done
  LINKS_DIR="${BUSYBOX_LINKS_DIR:-/usr/local/bin}"
  if [ -d "$LINKS_DIR" ]; then
    removed=0
    for f in "$LINKS_DIR"/*; do
      [ "${f##*/}" = busybox ] && continue
      [ -L "$f" ] || continue
      case "$(readlink "$f")" in
        */busybox/"$ARCH"/busybox) rm -f "$f" && removed=$((removed + 1)) ;;
      esac
    done
    if [ "$removed" -gt 0 ]; then
      handled=1
      printf '已移除 %s 个工具箱 busybox applet 链接（%s）\n' "$removed" "$LINKS_DIR"
    fi
  fi
  if [ "$handled" -eq 0 ]; then
    printf '未发现工具箱 busybox 的默认化痕迹（检查了 %s 与 %s）\n' "$SYS_BB_CANDIDATES" "$LINKS_DIR"
  fi
}

# --unset 走轻路径：不依赖仓库/校验，工具箱损坏也能还原
if [ "$UNSET_DEFAULT_BUSYBOX" -eq 1 ]; then
  unset_default_busybox
  exit $?
fi

# ── 常规安装：拷贝当前架构二进制到目标目录 ──────────────────────────
DEST="${DEST:-$HOME/.local/bin}"
mkdir -p "$DEST" || { printf '✗ 无法创建 %s\n' "$DEST" >&2; exit 1; }
echo "→ 架构 $ARCH，目标 $DEST"

ok=0; skip=0
for f in "$SRC"/*/"$ARCH"/*; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"

  # python3：单文件自解压壳直装 + python 别名
  case "$name" in
    python3)
      if cp -f "$f" "$DEST/python3" && chmod +x "$DEST/python3"; then
        ln -sf python3 "$DEST/python"
        echo "  ✓ python3  (单文件自解压壳 + python 别名)"
        ok=$((ok + 1)); continue
      else
        echo "  ✗ python3 安装失败"; skip=$((skip + 1)); continue
      fi ;;
  esac

  # 架构校验：不信文件名，读 ELF 头第 18 字节
  em=$(od -An -tx1 -j18 -N1 "$f" 2>/dev/null | tr -d ' \n')
  [ "$em" = "$EM" ] || { echo "  ✗ $name 架构不符（$em ≠ $EM）"; skip=$((skip + 1)); continue; }

  cp -f "$f" "$DEST/$name" && chmod +x "$DEST/$name" \
    && { printf '  ✓ %-8s %s\n' "$name" "$(awk -v s=$(wc -c < "$DEST/$name") 'BEGIN{printf "%.1fMB", s/1048576}')"; ok=$((ok + 1)); }
done

echo
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo "⚠ $DEST 不在 PATH 中，加这一行到 ~/.ashrc："; echo "    PATH=\"\$PATH:$DEST\"" ;;
esac
echo "✓ 装好 $ok 个（$ARCH）${skip:+，跳过 $skip}"

if [ "$SET_DEFAULT_BUSYBOX" -eq 1 ]; then
  echo
  printf '→ 设定工具箱 BusyBox 为系统默认终端（模式：%s）\n' "$(default_busybox_mode)"
  set_default_busybox || exit 1
fi
