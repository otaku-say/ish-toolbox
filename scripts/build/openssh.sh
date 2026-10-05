#!/bin/sh
# =============================================================================
# openssh.sh —— OpenSSH 客户端套件（全静态 musl + LibreSSL）
# -----------------------------------------------------------------------------
# 运行位置：Alpine chroot / native 内（由 curl.sh 拷入 /build 并调用）
# 前置条件：curl.sh 已在本环境构建 LibreSSL 到 /usr（libcrypto.a / libssl.a + 头）
#
# 产物（7 个全静态二进制，落在 /build/）：
#   ssh.static  scp.static  sftp.static  ssh-keygen.static
#   ssh-keyscan.static  ssh-agent.static  ssh-add.static
#
# 验收：静态判据 + ssh -V(LibreSSL) + 算法面 + 本机 sshd 端到端
#       （ssh exec / scp 上传比对 / sftp 下载 / ssh-keyscan 采集）
#
# 为什么选 OpenSSH 而非 Dropbear dbclient（2026-10 决策）：
#   功能面（ssh_config / ProxyJump / 端口转发 / sftp / scp / 证书）与生态一致性
#   的权重远高于体积（红线 64MB，当前仅用 ~22MB）；且与既有 LibreSSL 配方
#   同链复用，增量成本小。dbclient 唯一优势是小（~250KB），此处不构成约束。
# =============================================================================
set -eu

JOBS=${JOBS:-2}
OPENSSH_VER=${OPENSSH_VER:-10.5p1}
cd /build
E=/build/evidence.txt
[ -f "$E" ] || : > "$E"
FAILS=0
say() { echo "$@" | tee -a "$E"; }
ok()  { say "[PASS] $*"; }
bad() { say "[FAIL] $*"; FAILS=$((FAILS+1)); }

# ---------------- [s1] 前置检查 & 源码 ----------------
[ -f /usr/lib/libcrypto.a ] || { echo "FATAL: 缺 LibreSSL 静态库（须先完成 curl.sh 的 LibreSSL 阶段）" | tee -a "$E"; exit 1; }
DLC=/build/curl.static
[ -x "$DLC" ] || DLC=curl
if [ ! -f "openssh-$OPENSSH_VER.tar.gz" ]; then
  say "---- 下载 openssh-$OPENSSH_VER.tar.gz ----"
  "$DLC" -fsSL --max-time 180 -o "openssh-$OPENSSH_VER.tar.gz" \
      "https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-$OPENSSH_VER.tar.gz" \
    || "$DLC" -fsSL --max-time 180 -o "openssh-$OPENSSH_VER.tar.gz" \
      "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-$OPENSSH_VER.tar.gz" \
    || { bad "OpenSSH 源码下载失败"; exit 1; }
fi
sha256sum "openssh-$OPENSSH_VER.tar.gz" | tee -a "$E"

# ---------------- [s2] 构建依赖 ----------------
apk add --no-cache zlib-static >/dev/null 2>&1 || true
# openssh-server / sftp-server 仅用于本机端到端验收（不进入交付产物）
# 踩坑点：Alpine 的 sftp-server 是独立子包，缺它会导致 scp（默认走 SFTP 协议）/sftp 失败
apk add --no-cache openssh-server openssh-sftp-server >/dev/null 2>&1 \
  || apk add --no-cache openssh-server >/dev/null 2>&1 \
  || say "[WARN] openssh-server/sftp-server 安装失败：端到端验收将跳过"

# ---------------- [s3] 配置 + 构建 ----------------
rm -rf "openssh-$OPENSSH_VER"
tar xzf "openssh-$OPENSSH_VER.tar.gz"
cd "openssh-$OPENSSH_VER"
say "---- configure ----"
# 踩坑点：prefix 决定 SSH_PROGRAM（scp/sftp 拉起传输层 ssh 的编译期路径，
# 见 Makefile.in: SSH_PROGRAM=@bindir@/ssh）。设备上 ssh 装在 /usr/local/bin
# （install.sh 的 wrapper 位置），故用 --prefix=/usr/local 对齐，scp/sftp 才能找到它。
./configure \
  --prefix=/usr/local \
  --sysconfdir=/etc/ssh \
  --with-ssl-dir=/usr \
  --without-pam --without-kerberos5 --without-shadow \
  --disable-utmp --disable-utmpx --disable-wtmp --disable-lastlog \
  --with-zlib=/usr \
  --with-ldflags="-static -no-pie" \
  > /build/openssh-configure.log 2>&1 \
  || { tail -30 /build/openssh-configure.log | tee -a "$E"; bad "configure 失败"; exit 1; }
say "configure OK"

say "---- make -j$JOBS（7 个目标）----"
# 踩坑点：openssh 的 Makefile 把 LDFLAGS 定义成 "-L. -Lopenbsd-compat/ @LDFLAGS@"
# （链接时的 -lssh / -lopenbsd-compat 指向构建目录内的内部静态库）。命令行整体
# 覆盖 LDFLAGS 会连 -L 前缀一起冲掉 → ld 报 "cannot find -lssh"。此处显式保留
# -L 前缀再叠加静态旗标（与 configure --with-ldflags 双保险）。
if ! make -j"$JOBS" ssh scp sftp ssh-keygen ssh-keyscan ssh-agent ssh-add \
     LDFLAGS="-L. -Lopenbsd-compat/ -static -no-pie" \
     > /build/openssh-make.log 2>&1; then
  tail -40 /build/openssh-make.log | tee -a "$E"
  bad "make 失败"
  exit 1
fi
say "make OK"

# ---------------- [s4] 逐二进制：静态判据 + strip + 落盘 ----------------
for b in ssh scp sftp ssh-keygen ssh-keyscan ssh-agent ssh-add; do
  if [ ! -f "$b" ]; then bad "$b 未产出"; continue; fi
  if file "$b" | grep -q 'statically linked'; then
    strip "$b" 2>/dev/null || true
    cp "$b" "/build/$b.static"
    ok "$b 静态链接（$(wc -c < "/build/$b.static") bytes，stripped）"
  else
    bad "$b 非静态：$(file -b "$b")"
  fi
done
[ "$FAILS" = 0 ] || { say "OPENSSH-SUMMARY: FAIL=$FAILS（中止）"; exit 1; }

# ---------------- [s5] 版本与算法面 ----------------
V=$(./ssh -V 2>&1) || true
say "ssh -V => $V"
case "$V" in
  *OpenSSH*LibreSSL*) ok "ssh -V 含 OpenSSH + LibreSSL" ;;
  *) bad "ssh -V 异常（期望 OpenSSH + LibreSSL）: $V" ;;
esac
./ssh -Q kex 2>/dev/null | grep -q 'curve25519-sha256' && ok "KEX 含 curve25519-sha256" || bad "KEX 列表缺 curve25519-sha256"
./ssh -Q key 2>/dev/null | grep -q 'ssh-ed25519' && ok "KEY 含 ssh-ed25519" || bad "KEY 列表缺 ssh-ed25519"

# ---------------- [s6] 端到端：本机 sshd（用我们的客户端） ----------------
if [ -x /usr/sbin/sshd ]; then
  # 把套件装进 /usr/local/bin —— scp/sftp 会 exec /usr/local/bin/ssh（SSH_PROGRAM），
  # 与设备安装布局一致；E2E 即验证“完整套件协同工作”
  mkdir -p /usr/local/bin
  for b in ssh scp sftp ssh-keygen ssh-keyscan ssh-agent ssh-add; do
    cp "/build/$b.static" "/usr/local/bin/$b"
  done
  mkdir -p /run/sshd /root/.ssh
  chmod 700 /root/.ssh
  ssh-keygen -A >/dev/null 2>&1 || true
  ./ssh-keygen -q -t ed25519 -f /build/tk -N '' || bad "客户端密钥生成失败"
  cp /build/tk.pub /root/.ssh/authorized_keys 2>/dev/null || bad "authorized_keys 写入失败"
  chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true
  /usr/sbin/sshd -p 2222 -o PermitRootLogin=yes -o PasswordAuthentication=no -o UsePAM=no 2>/build/sshd.log || true
  CO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=8"

  # 1) ssh 远程执行（sshd 启动有竞态，重试 3 次）
  try=0; out=""
  while [ "$try" -lt 3 ]; do
    out=$(timeout 30 ./ssh -p 2222 $CO -i /build/tk root@127.0.0.1 'echo E2E-OK' 2>&1) || true
    case "$out" in *E2E-OK*) break ;; esac
    try=$((try+1)); sleep 2
  done
  case "$out" in
    *E2E-OK*) ok "端到端 ssh 远程执行" ;;
    *) bad "端到端 ssh 失败：$out"
       say "---- sshd.log 尾部 ----"; tail -15 /build/sshd.log 2>/dev/null | tee -a "$E" || true ;;
  esac

  # 2) scp 上传 + 字节比对（现代 scp 走 SFTP 协议，需要远端 sftp-server 子系统）
  timeout 30 ./scp -P 2222 $CO -i /build/tk /build/cacert.pem root@127.0.0.1:/tmp/scp-test.pem >/tmp/scp-out 2>&1 || true
  if cmp -s /build/cacert.pem /tmp/scp-test.pem; then
    ok "端到端 scp 上传字节一致"
  else
    bad "端到端 scp 失败：$(tail -2 /tmp/scp-out 2>/dev/null | tr '\n' ' ')"
  fi

  # 3) sftp 下载（用一定存在的 /etc/passwd 做样本）
  printf 'get /etc/passwd /tmp/remote-passwd\n' | timeout 30 ./sftp -P 2222 $CO -i /build/tk -b - root@127.0.0.1 >/tmp/sftp-out 2>&1 || true
  if [ -s /tmp/remote-passwd ]; then
    ok "端到端 sftp 下载（$(wc -c < /tmp/remote-passwd) bytes）"
  else
    bad "端到端 sftp 失败：$(tail -2 /tmp/sftp-out 2>/dev/null | tr '\n' ' ')"
  fi

  # 4) ssh-keyscan
  n=$(timeout 20 ./ssh-keyscan -p 2222 -T 5 127.0.0.1 2>/dev/null | grep -c 'ssh-' || true)
  if [ "${n:-0}" -ge 1 ] 2>/dev/null; then ok "端到端 ssh-keyscan（$n 条主机公钥）"; else bad "端到端 ssh-keyscan 失败"; fi

  kill "$(cat /run/sshd.pid 2>/dev/null)" 2>/dev/null || true
else
  say "[WARN] 无 sshd：跳过端到端验收"
fi

# ---------------- [s7] 收尾 ----------------
say "OPENSSH-SUMMARY: FAIL=$FAILS ；产物："
sha256sum /build/ssh.static /build/scp.static /build/sftp.static /build/ssh-keygen.static /build/ssh-keyscan.static /build/ssh-agent.static /build/ssh-add.static 2>/dev/null | tee -a "$E" || true
ls -l /build/ssh.static /build/scp.static /build/sftp.static /build/ssh-keygen.static /build/ssh-keyscan.static /build/ssh-agent.static /build/ssh-add.static 2>/dev/null | tee -a "$E" || true
[ "$FAILS" = 0 ] || exit 1
exit 0
