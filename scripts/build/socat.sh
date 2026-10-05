#!/bin/sh
# =============================================================================
# socat.sh —— socat（全静态 musl + LibreSSL，TLS 全功能）
# -----------------------------------------------------------------------------
# 运行位置：Alpine chroot / native 内（由 curl.sh 拷入 /build 并调用）
# 前置条件：curl.sh 已构建 LibreSSL 到 /usr（libssl.a / libcrypto.a + 头）
# 产物：/build/socat.static
# 验收：静态判据 + 版本行 + TCP 回环（单向）+ TLS 回环（自签证书，OPENSSL-LISTEN/CONNECT）
# =============================================================================
set -eu
JOBS=${JOBS:-2}
SOCAT_VER=${SOCAT_VER:-1.8.1.3}
cd /build
E=/build/evidence.txt
[ -f "$E" ] || : > "$E"
FAILS=0
say() { echo "$@" | tee -a "$E"; }
ok()  { say "[PASS] $*"; }
bad() { say "[FAIL] $*"; FAILS=$((FAILS+1)); }

[ -f /usr/lib/libssl.a ] || { echo "FATAL: 缺 LibreSSL 静态库（须先完成 curl.sh 的 LibreSSL 阶段）" | tee -a "$E"; exit 1; }
DLC=/build/curl.static
[ -x "$DLC" ] || DLC=curl
if [ ! -f "socat-$SOCAT_VER.tar.gz" ]; then
  say "---- 下载 socat-$SOCAT_VER.tar.gz ----"
  # 站点的 https 证书主机名不匹配（www.clausfischer.com），http 才是可靠首选
  "$DLC" -fsSL --max-time 120 -o "socat-$SOCAT_VER.tar.gz" \
      "http://www.dest-unreach.org/socat/download/socat-$SOCAT_VER.tar.gz" \
    || "$DLC" -fsSL --max-time 120 -o "socat-$SOCAT_VER.tar.gz" \
      "https://www.dest-unreach.org/socat/download/socat-$SOCAT_VER.tar.gz" \
    || { bad "socat 源码下载失败"; exit 1; }
fi
sha256sum "socat-$SOCAT_VER.tar.gz" | tee -a "$E"

rm -rf "socat-$SOCAT_VER"
tar xzf "socat-$SOCAT_VER.tar.gz"
cd "socat-$SOCAT_VER"
say "---- configure ----"
./configure --prefix=/usr --enable-openssl --disable-readline LDFLAGS="-static -no-pie" \
  > /build/socat-configure.log 2>&1 \
  || { tail -30 /build/socat-configure.log | tee -a "$E"; bad "socat configure 失败"; exit 1; }
grep -i 'openssl' /build/socat-configure.log | tail -3 | tee -a "$E" || true
say "configure OK"

say "---- make ----"
if ! make -j"$JOBS" socat LDFLAGS="-static -no-pie" > /build/socat-make.log 2>&1; then
  tail -40 /build/socat-make.log | tee -a "$E"
  bad "socat make 失败"
  exit 1
fi
say "make OK"

[ -f socat ] || { bad "socat 未产出"; exit 1; }
file socat | grep -q 'statically linked' || { bad "socat 非静态：$(file -b socat)"; exit 1; }
strip socat 2>/dev/null || true
cp socat /build/socat.static
ok "socat 静态链接（$(wc -c < /build/socat.static) bytes，stripped）"

# socat -V 第一行是版权行，版本号在后续行（1.8.x：第二行 "socat version x.y.z"）
V=$(./socat -V 2>&1) || true
say "socat -V（前 2 行）=> $(echo "$V" | head -2 | tr '\n' ' ')"
case "$V" in *socat*version*) ok "版本行正常" ;; *) bad "版本行异常: $(echo "$V" | head -2 | tr '\n' ' ')" ;; esac
echo "$V" | grep -i 'openssl' | head -2 | tee -a "$E" || true

# ---------------- 功能回环 1：TCP（单向） ----------------
./socat -u TCP-LISTEN:29001,reuseaddr,fork - > /tmp/socat-tcp.out 2>/tmp/socat-tcp.err &
TCPPID=$!
sleep 1
i=0; while [ "$i" -lt 3 ]; do
  echo "SOCAT-TCP-OK" | timeout 10 ./socat -u - TCP:127.0.0.1:29001 && break
  i=$((i+1)); sleep 1
done
sleep 1
kill "$TCPPID" 2>/dev/null || true
if grep -q 'SOCAT-TCP-OK' /tmp/socat-tcp.out 2>/dev/null; then
  ok "TCP 回环（单向传输）"
else
  bad "TCP 回环失败：$(tail -2 /tmp/socat-tcp.err 2>/dev/null | tr '\n' ' ')"
fi

# ---------------- 功能回环 2：TLS（自签证书） ----------------
openssl req -x509 -newkey rsa:2048 -nodes -keyout /tmp/sk.pem -out /tmp/sc.pem \
  -days 2 -subj /CN=127.0.0.1 >/dev/null 2>&1 || bad "自签证书生成失败"
./socat OPENSSL-LISTEN:29002,reuseaddr,fork,cert=/tmp/sc.pem,key=/tmp/sk.pem,verify=0 - \
  > /tmp/socat-tls.out 2>/tmp/socat-tls.err &
TLSPID=$!
sleep 1
i=0; while [ "$i" -lt 3 ]; do
  echo "SOCAT-TLS-OK" | timeout 10 ./socat - OPENSSL:127.0.0.1:29002,verify=0 && break
  i=$((i+1)); sleep 1
done
sleep 1
kill "$TLSPID" 2>/dev/null || true
if grep -q 'SOCAT-TLS-OK' /tmp/socat-tls.out 2>/dev/null; then
  ok "TLS 回环（自签证书，OPENSSL 地址族生效）"
else
  bad "TLS 回环失败：$(tail -2 /tmp/socat-tls.err 2>/dev/null | tr '\n' ' ')"
fi

say "SOCAT-SUMMARY: FAIL=$FAILS ；产物："
sha256sum /build/socat.static | tee -a "$E"
ls -l /build/socat.static | tee -a "$E"
[ "$FAILS" = 0 ] || exit 1
exit 0
