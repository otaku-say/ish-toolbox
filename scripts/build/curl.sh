#!/bin/sh
# =============================================================================
# curl.sh — LibreSSL 4.3.3 + curl 8.22.0 + OpenSSH 客户端套件 → 全静态 musl
# -----------------------------------------------------------------------------
# 目标: 单文件全静态 curl（TLS=LibreSSL；CA 内嵌 --with-ca-embed；
# 同配方附带产出：①全静态 openssl CLI（LibreSSL apps；s_client / 证书 / 摘要）
#                ②OpenSSH 客户端套件 7 件（ssh/scp/sftp/ssh-keygen/ssh-keyscan/
#                  ssh-agent/ssh-add；配方 scripts/build/openssh.sh 随 chroot 带入）
#       zlib/brotli/zstd/nghttp2 支持；不依赖任何运行时修复文件。
# 同配方附带：③drill（ldns 1.9.2；DNS 查询 + DNSSEC 签名链验证；
#              配方 scripts/build/drill.sh 随 chroot 带入，静态库复用本链的 LibreSSL）
# 实测记录: 2026-10-05 于 CubeSandbox 沙箱
#   （宿主 Ubuntu 22.04.5 容器 / root / x86_64 / 2 vCPU / 1.9GB RAM）
#   guest = Alpine v3.22.6 minirootfs（musl, gcc 14.2.0）
#   全部验收项 PASS（原始输出见 /tmp/evidence.txt）。
#
# 用法:
#   sh curl.sh                # root Linux 主机（自动用 Alpine chroot 构建）
#   CLEAN=1 sh curl.sh        # 从零重建（清空 chroot 与缓存）
#   REBUILD_SSL=1 sh curl.sh  # 强制重编 LibreSSL
#   （若已在 Alpine ≥3.22 的 root 环境内 → 自动切 native 模式，直接原地构建）
#
# 产物:
#   /tmp/curl.static      —— 静态 curl（= chroot 内 /build/curl.static）
#   /tmp/openssl.static   —— 静态 openssl CLI（= chroot 内 /build/openssl.static）
#   /tmp/{ssh,scp,sftp,ssh-keygen,ssh-keyscan,ssh-agent,ssh-add}.static —— OpenSSH 套件
#   /tmp/evidence.txt     —— 验收输出汇总（含各步输出与 sha256）
#   /tmp/curl.sh  —— 本脚本自身副本
#
# 环境依赖: root、网络、curl、tar(含 xz)、chroot、mknod（补 /dev 设备节点）
# =============================================================================
set -eu

# ---------------- 固定版本（可复现性优先；升级只动这里） ----------------
ALPINE_BRANCH=${ALPINE_BRANCH:-v3.22}
ALPINE_VER=${ALPINE_VER:-3.22.6}
LIBRESSL_VER=${LIBRESSL_VER:-4.3.3}
CURL_VER=${CURL_VER:-8.22.0}
JOBS=${JOBS:-2}
WORK=${WORK:-/tmp/alpine}

trap 'rc=$?; echo "===RECIPE-EXIT rc=$rc==="' EXIT
log() { echo; echo "====[$1] $2"; }

case "$(uname -m)" in
  x86_64)  ARCH=x86_64 ;;
  aarch64) ARCH=aarch64 ;;
  *) echo "FATAL: unsupported arch $(uname -m)"; exit 1 ;;
esac
DL_BASE="https://dl-cdn.alpinelinux.org/alpine/$ALPINE_BRANCH"
AMR="alpine-minirootfs-$ALPINE_VER-$ARCH.tar.gz"
SRC_SSL="https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-$LIBRESSL_VER.tar.gz"
SRC_CURL="https://curl.se/download/curl-$CURL_VER.tar.xz"
SRC_CA="https://curl.se/ca/cacert.pem"

# 脚本自身所在目录（顶部固定；避免后续 cd 改变 cwd 后 $0 相对路径解析失败）
HERE="$(cd "$(dirname "$0")" && pwd)"

# ---------------- [0] 模式判定 ----------------
if [ -f /etc/alpine-release ]; then
  MODE=native
  BUILD_DIR=/build
  log 0 "native Alpine build: $(cat /etc/alpine-release) ($ARCH), 无 chroot"
  mkdir -p "$BUILD_DIR"
else
  MODE=chroot
  log 0 "chroot build: host=$(uname -s) $(uname -m) / guest=Alpine $ALPINE_VER $ARCH"

  # ---------------- [1] Alpine minirootfs ----------------
  cd /tmp
  [ -f "$AMR" ] || curl -fLo "$AMR" "$DL_BASE/releases/$ARCH/$AMR"
  if [ "${CLEAN:-0}" = 1 ] || [ ! -x "$WORK/bin/busybox" ]; then
    rm -rf "$WORK"
    mkdir -p "$WORK"
    tar xzf "$AMR" -C "$WORK"
  fi
  # minirootfs 内 /dev 为空（不含设备节点），必须手动补齐，否则工具链无法工作
  mkdir -p "$WORK/dev"
  for node in "null c 1 3" "zero c 1 5" "random c 1 8" "urandom c 1 9" "tty c 5 0"; do
    set -- $node
    [ -e "$WORK/dev/$1" ] || mknod -m 666 "$WORK/dev/$1" "$2" "$3" "$4"
  done
  cp /etc/resolv.conf "$WORK/etc/resolv.conf"
  printf '%s\n' "$DL_BASE/main" "$DL_BASE/community" > "$WORK/etc/apk/repositories"
  BUILD_DIR="$WORK/build"
  mkdir -p "$BUILD_DIR"
fi

EV="$BUILD_DIR/evidence.txt"

# ---------------- [2] 源码下载（幂等） ----------------
cd "$BUILD_DIR"
[ -f "libressl-$LIBRESSL_VER.tar.gz" ] || curl -fLo "libressl-$LIBRESSL_VER.tar.gz" "$SRC_SSL"
[ -f "curl-$CURL_VER.tar.xz" ] || curl -fLo "curl-$CURL_VER.tar.xz" "$SRC_CURL"
[ -f cacert.pem ] || curl -fLo cacert.pem "$SRC_CA"
sha256sum "libressl-$LIBRESSL_VER.tar.gz" "curl-$CURL_VER.tar.xz" cacert.pem > "$BUILD_DIR/source-sha256.txt"
cat "$BUILD_DIR/source-sha256.txt"

# ---------------- [3] 生成 chroot 内部脚本 ----------------
cat > "$BUILD_DIR/inner.sh" <<'INNER_EOF'
#!/bin/sh
# 在 Alpine（chroot 或 native）内执行。版本常量需与宿主部分保持一致。
set -eu
LIBRESSL_VER=4.3.3
CURL_VER=8.22.0
JOBS=${JOBS:-2}
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
cd /build
E=/build/evidence.txt

log() { echo; echo "====[inner:$1] $2"; }

# ---------------- [i1] 构建依赖（实测生效的完整包清单） ----------------
log 3 "apk add 构建依赖"
if ! apk update; then
  echo "WARN: https 源 apk update 失败, 切 http 重试"
  sed -i 's|^https://|http://|' /etc/apk/repositories
  apk update
fi
PKGS="build-base perl linux-headers zlib-dev zlib-static brotli-dev brotli-static zstd-dev zstd-static nghttp2-dev nghttp2-static pkgconf file binutils"
if ! apk add --no-cache $PKGS; then
  echo "WARN: 批量安装失败, 逐包安装并记录跳过项"
  apk update || true
  for p in $PKGS; do apk add "$p" || echo "WARN: apk add $p FAILED"; done
fi
{ apk info -v 2>&1 || apk list --installed 2>&1; } | sort > /build/pkg-versions.txt
echo "---- 已装包（前 40 行） ----"; head -40 /build/pkg-versions.txt

log 3 "静态链接探针 + 静态库清点"
printf 'int main(void){return 0;}\n' > /tmp/probe.c
cc -static -no-pie /tmp/probe.c -o /tmp/probe && echo "PROBE: -static -no-pie OK" || { echo "PROBE: FAILED"; exit 1; }
for f in /usr/lib/libz.a /usr/lib/libzstd.a /usr/lib/libnghttp2.a /usr/lib/libbrotlidec.a /usr/lib/libbrotlicommon.a; do
  [ -f "$f" ] || { echo "FATAL: 缺少静态库 $f"; exit 1; }
  echo "  static: $f"
done
ls /usr/lib/libdl* /usr/lib/libpthread* 2>/dev/null || echo "NOTE: 无 libdl/libpthread 桩（musl 相应符号在 libc.a 内）"

# ---------------- [i2] LibreSSL ----------------
log 4 "LibreSSL $LIBRESSL_VER"
if [ -f /usr/lib/libcrypto.a ] && [ -f /usr/lib/libssl.a ] && [ -f /build/.libressl.done2 ] && [ "${REBUILD_SSL:-0}" != 1 ]; then
  echo "SKIP: LibreSSL 已就绪（REBUILD_SSL=1 可强制重建）"
else
  rm -rf "libressl-$LIBRESSL_VER"
  tar xzf "libressl-$LIBRESSL_VER.tar.gz"
  cd "libressl-$LIBRESSL_VER"
  # iSH 适配（otaku-say/ish-toolbox，2026-10）三补丁：
  #   ① openssldir=/etc/ssl（对齐 iSH 证书文件位置；见下方 configure 行）
  #   ② 内嵌 CA bundle 注入默认证书库（无任何文件也能默认验链）
  #   ③ 默认配置缺失/损坏（如 iSH/Alpine 自带的 OpenSSL3 式 providers）→
  #      内嵌最小配置兜底，不再 "Auto configuration failed" exit(1)
  patch -p1 < /build/libressl-ishfix.patch
  sh /build/gen-embed.sh
  # 踩坑点(1): LibreSSL 基于 libtool，configure --help 只列 --enable-shared/
  # --enable-static，并不出现 "--disable-shared" 字样 —— 不能写 grep 探测，
  # 直接显式传参（autoconf 完整接受 --disable-shared 否定形式）。
  ./configure --prefix=/usr --disable-shared --enable-static --with-openssldir=/etc/ssl
  # 踩坑点(3): libtool 项目，apps 必须用 -all-static 才会静态链接最终程序
  make -j"$JOBS" LDFLAGS="-no-pie -all-static" || { echo "WARN: make -j$JOBS 失败, 回退 -j1 重试"; make -j1 LDFLAGS="-no-pie -all-static"; }
  make install
  cd /build
  touch /build/.libressl.done2
fi
ls -l /usr/lib/libcrypto.a /usr/lib/libssl.a /usr/lib/libtls.a

# ---- openssl CLI：全静态交付（随 LibreSSL 一起构建）----
if [ ! -f /build/openssl.static ]; then
  file /usr/bin/openssl 2>/dev/null | grep -q 'statically linked' \
    || { echo "FATAL: /usr/bin/openssl 非全静态"; file /usr/bin/openssl; exit 1; }
  cp /usr/bin/openssl /build/openssl.static
  strip /build/openssl.static 2>/dev/null || true
fi
ls -l /build/openssl.static
sha256sum /build/openssl.static

# ---------------- [i3] curl ----------------
log 5 "curl $CURL_VER"
rm -rf "curl-$CURL_VER"
tar xJf "curl-$CURL_VER.tar.xz"
cd "curl-$CURL_VER"
echo "---- pkg-config 静态闭包（记录用） ----"
pkg-config --libs --static libbrotlidec libzstd libnghttp2 2>&1 || true
./configure \
  --prefix=/usr \
  --disable-shared --enable-static \
  --with-openssl=/usr \
  --with-ca-embed=/build/cacert.pem \
  --without-ca-bundle --without-ca-path \
  --with-zlib --with-brotli --with-zstd --with-nghttp2 \
  --without-libpsl \
  --disable-ldap --disable-ldaps \
  LDFLAGS="-static -no-pie" \
  LIBS="-lbrotlicommon"
# 踩坑点(2): LDFLAGS 里的 -static 会被 libtool 当作自身控制参数吞掉（它只把
# .la 依赖静态化），系统 -lssl/-lzstd... 仍是动态。必须用 libtool 的 -all-static，
# 它才会把 -static 透传给最终 gcc 链接命令 → file(1) 显示 "statically linked"。
make -j"$JOBS" LDFLAGS="-no-pie -all-static" || { echo "WARN: -all-static 失败, 回退 -static -no-pie"; make -j1 LDFLAGS="-no-pie -static"; }
# 定位产物（libtool 某些布局下真身在 .libs/）
BIN=src/curl
if ! file src/curl 2>/dev/null | grep -q ELF; then BIN=src/.libs/curl; fi
file "$BIN" | grep -q ELF || { echo "FATAL: 未找到 ELF 产物"; ls -l src src/.libs 2>/dev/null; exit 1; }
file "$BIN" | grep -q 'statically linked' || { echo "FATAL: 产物非全静态（libtool/-all-static 行为可能已变）"; file "$BIN"; exit 1; }
strip "$BIN"
cp "$BIN" /build/curl.static
ls -l /build/curl.static
sha256sum /build/curl.static

# ---------------- [i4] 验收 ----------------
log 6 "验收（输出同时写入 $E）"
V=/build/curl.static
: > "$E"
FAILS=0
say() { echo "$@" | tee -a "$E"; }
sec() { say ""; say "-------- $* --------"; }
ok()  { say "[PASS] $*"; }
bad() { say "[FAIL] $*"; FAILS=$((FAILS+1)); }

sec "环境信息"
{
  echo "date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "guest: Alpine $(cat /etc/alpine-release) / $(uname -m) / kernel $(uname -r)"
  echo "gcc: $(cc --version | head -1)"
  echo "repos: $(head -2 /etc/apk/repositories | tr '\n' ' ')"
} | tee -a "$E"
say "---- 源码 sha256 ----"
cat /build/source-sha256.txt | tee -a "$E"

sec "V1 file(1)"
file "$V" | tee -a "$E"
if file "$V" | grep -q 'statically linked'; then ok "file: statically linked"; else bad "file 非 statically linked"; fi

sec "V2 readelf -h"
readelf -h "$V" | grep -E 'Class:|Machine:|Type:' | tee -a "$E"

sec "V3 readelf -l（期望无 INTERP）"
readelf -l "$V" > /tmp/readelf-l.txt 2>&1 || true
cat /tmp/readelf-l.txt | tee -a "$E"
n_interp=$(grep -c INTERP /tmp/readelf-l.txt || true)
if [ "$n_interp" = 0 ]; then ok "readelf -l: 无 INTERP 行"; else bad "readelf -l: 有 INTERP x$n_interp"; fi

sec "V4 readelf -d（期望无 NEEDED）"
readelf -d "$V" > /tmp/readelf-d.txt 2>&1 || true
cat /tmp/readelf-d.txt | tee -a "$E"
n_needed=$(grep -c NEEDED /tmp/readelf-d.txt || true)
if [ "$n_needed" = 0 ]; then ok "readelf -d: 无 NEEDED 行"; else bad "readelf -d: 有 NEEDED x$n_needed"; fi
say "ldd 输出（参考）: $(ldd $V 2>&1 | tr '\n' ' ')"

sec "V5 curl --version"
"$V" --version | tee -a "$E"
LINE1=$("$V" --version | head -1)
case "$LINE1" in
  *LibreSSL*) ok "版本首行含 LibreSSL: $LINE1" ;;
  *) bad "版本首行不含 LibreSSL: $LINE1" ;;
esac

sec "V6 https://example.com/"
out=$("$V" -sS -o /dev/null -w '%{http_code}' https://example.com/ 2>&1) && rc=0 || rc=$?
say "exit=$rc output=[$out]"
if [ "$rc" = 0 ] && [ "$out" = 200 ]; then ok "example.com => 200"; else bad "example.com => rc=$rc [$out]"; fi

sec "V7 CA 内嵌（--dump-ca-embed）"
nca=$("$V" --dump-ca-embed | grep -c 'BEGIN CERTIFICATE' || true)
say "embedded cert count = $nca（期望 >= 50）"
if [ "$nca" -ge 50 ] 2>/dev/null; then ok "CA embed >= 50 ($nca)"; else bad "CA embed 数量不足 ($nca)"; fi

sec "V8 GitHub raw 下载（rg 工具）"
RG_URL=https://raw.githubusercontent.com/otaku-say/ish-toolbox/main/tools/rg/arm64/rg
code=$("$V" -sSL -o /build/dl-rg.bin --max-time 120 -w '%{http_code}' "$RG_URL" 2>/dev/null || true)
sz=$(wc -c < /build/dl-rg.bin 2>/dev/null || echo 0)
say "http_code=$code size=$sz"
say "file: $(file -b /build/dl-rg.bin 2>/dev/null)"
say "sha256: $(sha256sum /build/dl-rg.bin 2>/dev/null | cut -d' ' -f1)"
if [ "$code" = 200 ] && [ "$sz" -gt 100000 ] 2>/dev/null; then ok "github raw 下载成功 ($sz B)"; else bad "github raw code=$code size=$sz"; fi

sec "V9 HTTP/2（nghttp2）"
out=$("$V" --http2 -sS -o /dev/null -w '%{http_code} %{http_version}' https://curl.se/ 2>&1) && rc=0 || rc=$?
say "exit=$rc output=[$out]"
case "$out" in
  '200 2') ok "HTTP/2 协商成功（curl.se => $out, nghttp2 生效）" ;;
  *) bad "HTTP/2: rc=$rc [$out]" ;;
esac

say ""
sec "V10 openssl CLI（LibreSSL，全静态）"
O=/build/openssl.static
file "$O" | tee -a "$E"
file "$O" | grep -q 'statically linked' && ok "openssl 全静态" || bad "openssl 非全静态"
"$O" version 2>&1 | tee -a "$E"
ncert=$(echo | "$O" s_client -connect example.com:443 -servername example.com 2>&1 | grep -c 'BEGIN CERTIFICATE' || true)
say "s_client 证书链张数 = $ncert"
[ "$ncert" -ge 1 ] 2>/dev/null && ok "s_client 可用" || bad "s_client 异常"

say ""
sec "V10b openssl 默认行为（iSH 适配：缺配置 / 毒配置 / 默认验链）"
# 1) version -d 干净（无 warning/error 行）
nver=$("$O" version -d 2>&1 | grep -ci 'warning\|error' || true); say "version -d 警告/错误行 = $nver"
if [ "$nver" = 0 ]; then ok "openssl version -d 无警告"; else bad "openssl version -d 有 $nver 行警告"; fi
# 2) 毒配置在位也不炸（Alpine/iSH 自带的 OpenSSL3 式配置就是这种）
cp /etc/ssl/openssl.cnf /tmp/openssl.cnf.save 2>/dev/null || true
printf 'openssl_conf = openssl_init\nconfig_diagnostics = 1\n[openssl_init]\nproviders = provider_sect\n[provider_sect]\ndefault = default_sect\n' > /etc/ssl/openssl.cnf
"$O" req -x509 -newkey rsa:2048 -nodes -keyout /tmp/ik -out /tmp/ic -days 1 -subj /CN=t >/tmp/req.out 2>&1 && rc=0 || rc=$?
say "毒配置在位 req rc=$rc"
if [ "$rc" = 0 ]; then ok "毒配置在位 req 仍 rc=0（内嵌兜底生效）"; else bad "毒配置在位 req rc=$rc"; sed -n '1,3p' /tmp/req.out | tee -a "$E"; fi
if [ -f /tmp/openssl.cnf.save ]; then cp /tmp/openssl.cnf.save /etc/ssl/openssl.cnf; else rm -f /etc/ssl/openssl.cnf; fi
# 3) 默认验链（s_client）
ver=$("$O" s_client -connect example.com:443 -servername example.com </dev/null 2>&1 | grep -o 'Verify return code: [0-9]* ([^)]*)' | head -1)
say "s_client 默认验链: $ver"
case "$ver" in *"code: 0"*) ok "s_client 默认验链 rc=0";; *) bad "s_client 默认验链 $ver";; esac

# ---------------- [i5] 扩展套件（放在验收段之后：确保其 PASS/FAIL 计入证据与门禁） ----
# 注意：绝不能放在 [i4] 之前 —— [i4] 开头 `: > "$E"` 会清空证据文件、FAILS 也会被
# 重置为 0，导致扩展套件的失败被静默吞掉、整轮误判绿色（2026-10 实际踩过）。
if [ -f /build/openssh.sh ]; then
  log "5" "OpenSSH 客户端套件（静态）"
  if JOBS="${JOBS:-2}" sh /build/openssh.sh; then
    echo "[PASS] openssh 套件构建与端到端验收" | tee -a "$E"
  else
    echo "[FAIL] openssh 套件" | tee -a "$E"; FAILS=$((FAILS+1))
  fi
else
  echo "[WARN] /build/openssh.sh 缺失，跳过 openssh" | tee -a "$E"
fi
if [ -f /build/socat.sh ]; then
  log "5" "socat（TLS 全功能，静态）"
  if JOBS="${JOBS:-2}" sh /build/socat.sh; then
    echo "[PASS] socat 构建与验收" | tee -a "$E"
  else
    echo "[FAIL] socat" | tee -a "$E"; FAILS=$((FAILS+1))
  fi
else
  echo "[WARN] /build/socat.sh 缺失，跳过 socat" | tee -a "$E"
fi
if [ -f /build/drill.sh ]; then
  log "5" "drill（ldns：DNS 查询 / DNSSEC 验证，静态）"
  if JOBS="${JOBS:-2}" sh /build/drill.sh; then
    echo "[PASS] drill 构建与验收" | tee -a "$E"
  else
    echo "[FAIL] drill" | tee -a "$E"; FAILS=$((FAILS+1))
  fi
else
  echo "[WARN] /build/drill.sh 缺失，跳过 drill" | tee -a "$E"
fi

say "INNER-SUMMARY: PASS=$(grep -c '^\[PASS\]' "$E" || true) FAIL=$FAILS"
[ "$FAILS" = 0 ] || exit 1
INNER_EOF

# openssh / socat 配方随 chroot 带入（LibreSSL 就绪后由 inner 调用；产物即 /build/*.static）
if [ -f "$HERE/openssh.sh" ]; then
  cp "$HERE/openssh.sh" "$BUILD_DIR/openssh.sh"
else
  echo "WARN: scripts/build/openssh.sh 不存在，本次跳过 openssh 构建"
fi
if [ -f "$HERE/socat.sh" ]; then
  cp "$HERE/socat.sh" "$BUILD_DIR/socat.sh"
else
  echo "WARN: scripts/build/socat.sh 不存在，本次跳过 socat 构建"
fi
if [ -f "$HERE/drill.sh" ]; then
  cp "$HERE/drill.sh" "$BUILD_DIR/drill.sh"
else
  echo "WARN: scripts/build/drill.sh 不存在，本次跳过 drill 构建"
fi

# iSH 适配三件套（LibreSSL 源码补丁 + 内嵌头生成器 + 最小配置）
#   由 inner 在解包 LibreSSL 后应用；三个文件都必须随构建带入
cp "$HERE/libressl-ishfix.patch" "$BUILD_DIR/libressl-ishfix.patch"
cp "$HERE/gen-embed.sh" "$BUILD_DIR/gen-embed.sh"
cp "$HERE/libressl-min.cnf" "$BUILD_DIR/libressl-min.cnf"

INNER_RC=0
if [ "$MODE" = chroot ]; then
  chroot "$WORK" /bin/sh /build/inner.sh || INNER_RC=$?
else
  /bin/sh "$BUILD_DIR/inner.sh" || INNER_RC=$?
fi

# ---------------- [5] 隔离验收：最小根目录（证明 CA 内嵌 + 真静态） ----------------
if [ -f "$BUILD_DIR/curl.static" ]; then
  log 5 "隔离验收: 只有一个二进制 + resolv.conf 的空根目录（无任何 CA 文件）"
  HB=/tmp/hermetic-root
  rm -rf "$HB"; mkdir -p "$HB/etc" "$HB/dev"
  cp "$BUILD_DIR/curl.static" "$HB/curl"; chmod 755 "$HB/curl"
  cp /etc/resolv.conf "$HB/etc/resolv.conf"
  for node in "null c 1 3" "urandom c 1 9"; do
    set -- $node
    [ -e "$HB/dev/$1" ] || mknod -m 666 "$HB/dev/$1" "$2" "$3" "$4"
  done
  out=$(chroot "$HB" /curl -sS -o /dev/null -w '%{http_code}' https://example.com/ 2>&1) && rc=0 || rc=$?
  if [ "$rc" = 0 ] && [ "$out" = 200 ]; then
    echo "[PASS] hermetic: 空根目录 https://example.com/ => 200（CA 来自内嵌）" | tee -a "$EV"
  else
    echo "[FAIL] hermetic: 空根目录 https://example.com/ => rc=$rc out=[$out]" | tee -a "$EV"
  fi
  out=$(chroot "$HB" /curl --version 2>&1 | head -1) || true
  echo "[INFO] hermetic --version: $out" | tee -a "$EV"
else
  echo "[FAIL] 未生成 $BUILD_DIR/curl.static" | tee -a "$EV"
fi

# ---------------- [5b] openssl 隔离验收（内嵌 CA；根目录无任何 CA 文件） ----------------
if [ -f "$BUILD_DIR/openssl.static" ]; then
  if [ ! -d "$HB" ]; then
    HB=/tmp/hermetic-root; rm -rf "$HB"; mkdir -p "$HB/etc" "$HB/dev"
    cp /etc/resolv.conf "$HB/etc/resolv.conf"
    for node in "null c 1 3" "urandom c 1 9"; do
      set -- $node
      [ -e "$HB/dev/$1" ] || mknod -m 666 "$HB/dev/$1" "$2" "$3" "$4"
    done
  fi
  cp "$BUILD_DIR/openssl.static" "$HB/openssl"; chmod 755 "$HB/openssl"
  out=$(chroot "$HB" /openssl s_client -connect example.com:443 -servername example.com </dev/null 2>&1 | grep -o 'Verify return code: [0-9]* ([^)]*)' | head -1)
  case "$out" in
    *"code: 0"*) echo "[PASS] hermetic openssl: 空根目录默认验链 rc=0（CA 来自内嵌）" | tee -a "$EV" ;;
    *) echo "[FAIL] hermetic openssl: $out" | tee -a "$EV" ;;
  esac
fi

# ---------------- [6] 汇总与产出 ----------------
log 6 "汇总与产出"
[ -f "$EV" ] || : > "$EV"
P=$(grep -c '^\[PASS\]' "$EV" 2>/dev/null || true)
F=$(grep -c '^\[FAIL\]' "$EV" 2>/dev/null || true)
{
  echo ""
  echo "======== SUMMARY ========"
  echo "checks: PASS=$P FAIL=$F ; inner_build_rc=$INNER_RC"
  if [ "$F" = 0 ] && [ "$INNER_RC" = 0 ]; then echo "VERDICT: ALL-PASS"; else echo "VERDICT: HAS-FAILURES"; fi
} | tee -a "$EV"

if [ -f "$BUILD_DIR/curl.static" ]; then
  cp "$BUILD_DIR/curl.static" /tmp/curl.static
  [ -f "$BUILD_DIR/openssl.static" ] && cp "$BUILD_DIR/openssl.static" /tmp/openssl.static && sha256sum /tmp/openssl.static
  ls -l /tmp/curl.static
  sha256sum /tmp/curl.static
fi
# OpenSSH 套件 / socat 产物（若已构建）
for b in ssh scp sftp ssh-keygen ssh-keyscan ssh-agent ssh-add socat drill; do
  if [ -f "$BUILD_DIR/$b.static" ]; then
    cp "$BUILD_DIR/$b.static" "/tmp/$b.static"
    sha256sum "/tmp/$b.static"
  fi
done
cp "$EV" /tmp/evidence.txt
case "$0" in
  /tmp/curl.sh) ;;
  *) cp "$0" /tmp/curl.sh 2>/dev/null || true ;;
esac
echo "产物: /tmp/curl.static /tmp/openssl.static /tmp/{ssh,scp,sftp,ssh-keygen,ssh-keyscan,ssh-agent,ssh-add}.static /tmp/socat.static"
echo "证据: /tmp/evidence.txt ; 配方: /tmp/curl.sh"
[ "$F" = 0 ] && [ "$INNER_RC" = 0 ]

# =============================================================================
# GitHub CI 移植注意（Alpine 容器, aarch64 + amd64 双架构）
# -----------------------------------------------------------------------------
# 1) 最省事: 直接在 Alpine 容器里跑本脚本（job container: alpine:3.22）。
#    脚本检测到 /etc/alpine-release 会切 native 模式, 无需 chroot。
#    container 默认 root、自带 ca-certificates（apk https 源可用）。
# 2) 也可用 ubuntu runner 以本脚本原样跑（chroot 模式）——GitHub runner 允许
#    chroot + mknod, 但需 sudo / root。
# 3) 双架构: matrix 分别用 x86_64 与 aarch64 runner（aarch64 用 QEMU 或
#    ubuntu-*-arm / 自建 runner 均可）；脚本按 uname -m 自动选 minirootfs。
# 4) 归档: actions/upload-artifact 收 /tmp/curl.static + /tmp/evidence.txt。
# 5) 可复现: 全部版本号在脚本头部静态固定；源站用 dl-cdn / ftp.openbsd.org /
#    curl.se；如个别源被封, 换镜像并把 URL 变量改掉即可（无其它硬编码）。
# 6) 本配方要点（别随意删）:
#    - LibreSSL: ./configure --disable-shared --enable-static（libtool 项目，
#      help 里没有 "--disable-shared" 字样，别写探测逻辑）
#    - curl 最终链接: make LDFLAGS="-no-pie -all-static" —— libtool 会吞掉
#      LDFLAGS 里的 -static（只静态化 .la），-all-static 才产出真全静态；
#      configure 阶段仍用 LDFLAGS="-static -no-pie"（供探测/固化为默认值）
#    - LIBS="-lbrotlicommon"      → brotli 静态闭包（libbrotlidec.a 依赖 common）
#    - --with-ca-embed + --without-ca-bundle/ca-path → 证书完全内嵌
#    - minirootfs 的 /dev 为空 → 必须 mknod（脚本已处理）
# 7) Alpine 上的 musl 静态二进制 DNS 依赖 /etc/resolv.conf（运行时文件, 非修复文件），
#    这是 musl 静态的正常行为, iSH 的 Alpine 同样适用。
# =============================================================================
