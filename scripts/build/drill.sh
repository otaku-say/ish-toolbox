#!/bin/sh
# =============================================================================
# drill.sh —— drill（ldns 自带 DNS 查询 / DNSSEC 工具）→ 全静态 musl + LibreSSL
# -----------------------------------------------------------------------------
# 运行位置：Alpine chroot / native 内（由 curl.sh 拷入 /build 并在 LibreSSL 就绪后调用；
#           环境变量 JOBS 可用）。本脚本不含 chroot 相关逻辑，两种环境等价。
# 前置条件：curl.sh 已在本环境把 LibreSSL 装到 /usr（/usr/lib/{libcrypto,libssl}.a + 头）。
#           本脚本只构建 drill，不重建 LibreSSL（那是 curl.sh 的职责）；库缺失即报错退出。
# 产物：/build/drill.static（验收记录追加到 /build/evidence.txt）
# 验收：configure/make 原始日志要点 + 静态判据 + 版本行 + 真跑 example.com A 查询
#       + DNSSEC 签名链（-S：无锚定给结论；锚定验证成功；伪锚定负控制必须被拒）
# =============================================================================
set -eu

JOBS=${JOBS:-2}
LDNS_VER=${LDNS_VER:-1.9.2}
# ldns-1.9.2.tar.gz 官方 sha256（https://www.nlnetlabs.nl/downloads/ldns/ldns-1.9.2.tar.gz.sha256）
LDNS_SHA256=${LDNS_SHA256:-b524fa21994b6e834200ceb8c27f1b84bda5982fe35706f058196c079db94d5d}
cd /build
E=/build/evidence.txt
[ -f "$E" ] || : > "$E"
FAILS=0
say() { echo "$@" | tee -a "$E"; }
ok()  { say "[PASS] $*"; }
bad() { say "[FAIL] $*"; FAILS=$((FAILS+1)); }

say "drill.sh: env=Alpine $(cat /etc/alpine-release 2>/dev/null || echo '?') $(uname -m) JOBS=$JOBS ldns=$LDNS_VER"

# ---------------- [d1] 前置检查：LibreSSL 静态库（curl.sh 的产物） ----------------
if [ ! -f /usr/lib/libcrypto.a ] || [ ! -f /usr/lib/libssl.a ]; then
  echo "FATAL: 缺 LibreSSL 静态库（/usr/lib/libcrypto.a 或 /usr/lib/libssl.a 不在）——" | tee -a "$E"
  echo "FATAL: 请先完成 curl.sh 的 LibreSSL 阶段（本脚本不负责构建 LibreSSL）。" | tee -a "$E"
  exit 1
fi

# ---------------- [d2] 源码下载（幂等）+ sha256 校验 ----------------
if [ -x /build/curl.static ]; then
  DL() { /build/curl.static -fsSL --max-time 180 -o "$1" "$2"; }
elif command -v curl >/dev/null 2>&1; then
  DL() { curl -fsSL --max-time 180 -o "$1" "$2"; }
else
  DL() { wget -q -T 60 -O "$1" "$2"; }
fi
if [ ! -f "ldns-$LDNS_VER.tar.gz" ]; then
  say "---- 下载 ldns-$LDNS_VER.tar.gz ----"
  DL "ldns-$LDNS_VER.tar.gz" "https://www.nlnetlabs.nl/downloads/ldns/ldns-$LDNS_VER.tar.gz" \
    || DL "ldns-$LDNS_VER.tar.gz" "https://nlnetlabs.nl/downloads/ldns/ldns-$LDNS_VER.tar.gz" \
    || { bad "ldns 源码下载失败"; exit 1; }
fi
got=$(sha256sum "ldns-$LDNS_VER.tar.gz" | cut -d' ' -f1)
say "ldns-$LDNS_VER.tar.gz sha256 = $got"
[ "$got" = "$LDNS_SHA256" ] || { bad "sha256 与官方不符（期望 $LDNS_SHA256）"; exit 1; }
ok "sha256 与官方 .sha256 文件一致"

# ---------------- [d3] configure + make（全静态） ----------------
rm -rf "ldns-$LDNS_VER"
tar xzf "ldns-$LDNS_VER.tar.gz"
cd "ldns-$LDNS_VER"

say "---- configure ----"
# --with-drill            : ldns 1.9.x 默认不构建 drill（configure.ac 默认 with_drill=no），必须显式打开
# --with-ssl=/usr         : 指向 curl.sh 装好的 LibreSSL（静态 .a + 头文件）
# --disable-shared        : 只要静态库（drill 最终链接走 -all-static）
# --disable-dane-ta-usage : 兼容性开关（非"砍 DNSSEC"）。LibreSSL 4.3.3 不导出 SSL_get0_dane，
#   ldns 在 DANE-TA usage 型探测里硬性依赖它（configure.ac: AC_CHECK_FUNC(SSL_get0_dane)
#   失败即 AC_MSG_ERROR）。该符号在 dane.c 中仅出现于 #if defined(USE_DANE_TA_USAGE) 分支
#   （L733/L948），关掉 TA usage 型支持即可整体编译通过：DANE 主体与 DANE-verify 保留、
#   DNSSEC 全部代码路径（-S 签名链、验证、各算法）不受任何影响；且 drill 源码根本不引用
#   DANE（grep 为空），本脚本也只交付 drill（ldns-dane 不交付）。上游报错信息给出的正是
#   这两个选项：--disable-dane-verify / --disable-dane-ta-usage，这里取更小削减的前者。
./configure \
  --prefix=/usr \
  --disable-shared --enable-static \
  --with-drill \
  --with-ssl=/usr \
  --disable-dane-ta-usage \
  LDFLAGS="-static -no-pie" \
  > /build/ldns-configure.log 2>&1 \
  || { tail -40 /build/ldns-configure.log | tee -a "$E"; bad "drill configure 失败"; exit 1; }
say "configure OK"
grep -E "checking for (SSL|LibreSSL|EVP_sha256)" /build/ldns-configure.log | tee -a "$E" || true

say "---- make -j$JOBS drill ----"
# 踩坑点（与 curl.sh 同款实证）：libtool 项目里 LDFLAGS 的 -static 会被 libtool 吞掉
# （只静态化 .la 依赖），必须用 -all-static 才会把 -static 透传给最终 gcc 链接命令，
# 产出 file(1) 判定为 "statically linked" 的全静态二进制。
if ! make -j"$JOBS" drill LDFLAGS="-no-pie -all-static" > /build/ldns-make.log 2>&1; then
  echo "WARN: -all-static 失败，回退 -static 重试" | tee -a "$E"
  make -j1 drill LDFLAGS="-no-pie -static" > /build/ldns-make.log 2>&1 \
    || { tail -40 /build/ldns-make.log | tee -a "$E"; bad "drill make 失败"; exit 1; }
fi
say "make OK"
# 留证：最终链接命令 + 实际使用的 SSL 库闭包（回答"要不要额外的 -lz/-lpthread"）
grep -E "mode=link.*-o drill/drill" /build/ldns-make.log | tail -1 | tee -a "$E" || true
grep -E "^LIBSSL_LIBS|^LIBSSL_SSL_LIBS|^LIBS " Makefile | tee -a "$E" || true

# ---------------- [d4] 落盘 + 静态判据 ----------------
B=drill/drill
if ! file "$B" 2>/dev/null | grep -q ELF; then B=drill/.libs/drill; fi
[ -f "$B" ] || { bad "未找到 drill 产物"; ls -l drill drill/.libs 2>/dev/null | tee -a "$E" || true; exit 1; }
file "$B" | tee -a "$E"
file "$B" | grep -q 'statically linked' || { bad "drill 非全静态：$(file -b "$B")"; exit 1; }
strip "$B" 2>/dev/null || true
cp "$B" /build/drill.static
ok "drill 静态链接（$(wc -c < /build/drill.static) bytes，stripped）"

# ---------------- [d5] 版本行 + 真跑 ----------------
V=$(/build/drill.static -v 2>&1) && vrc=0 || vrc=$?
say "drill -v (rc=$vrc) => $(echo "$V" | head -1)"
case "$V" in *ldns*) ok "版本行正常（含 ldns version；-v 打印后即退出）" ;; *) bad "版本行异常" ;; esac
[ "$vrc" = 0 ] && ok "drill -v 退出码 0（CI 的 pack 版本旗标可直接用 'drill -v'）" || bad "drill -v 退出码 $vrc"

say "---- drill example.com @1.1.1.1 ----"
i=0; Q=""
while [ "$i" -lt 3 ]; do
  Q=$(timeout 30 /build/drill.static example.com @1.1.1.1 2>&1) || true
  case "$Q" in *"ANSWER SECTION"*) break ;; esac
  i=$((i+1)); sleep 2
done
echo "$Q" | tee -a "$E"
case "$Q" in *"ANSWER SECTION"*) ok "A 查询拿到 ANSWER SECTION" ;; *) bad "A 查询未拿到 ANSWER SECTION" ;; esac

say "---- drill -S example.com @1.1.1.1（无锚定，看默认行为） ----"
S0=$(timeout 45 /build/drill.static -S example.com @1.1.1.1 2>&1) || true
echo "$S0" | tail -20 | tee -a "$E"
# 明确结论：无 -k 且无 LDNS_TRUST_ANCHOR_FILE 时，drill 会提示缺信任锚、不做验证
case "$S0" in
  *"trusted keys"*) say "[INFO] 无锚定 -S：明确提示缺信任锚（未验证，符合预期）" ;;
  *) say "[INFO] 无锚定 -S 输出如上（人工复核）" ;;
esac

# 信任锚（两枚根 KSK 的 DS，来源 https://data.iana.org/root-anchors/root-anchors.xml）
# drill 的 read_key_file 接受 "." 开头的 DNSKEY/DS 行
cat > /build/drill-root.key <<'KEY_EOF'
; root trust anchors (KSK-2017 + KSK-2024), from IANA root-anchors.xml
. IN DS 20326 8 2 E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D
. IN DS 38696 8 2 683D2D0ACB8C9B712A1948B27F741219298D0A450D612C483AF444A4C0FB2B16
KEY_EOF

say "---- drill -S -V 3 -k /build/drill-root.key example.com @1.1.1.1（锚定） ----"
S1=$(timeout 60 /build/drill.static -S -V 3 -k /build/drill-root.key example.com @1.1.1.1 2>&1) && s1rc=0 || s1rc=$?
say "anchored rc=$s1rc"
echo "$S1" | tail -35 | tee -a "$E"
if echo "$S1" | grep -q "Chase successful" && echo "$S1" | grep -q "Number of trusted keys: 2"; then
  ok "DNSSEC 链（锚定）：Chase successful（信任链以根 KSK 验证，退出码 $s1rc）"
else
  bad "DNSSEC 链（锚定）未成功"
fi

# 负控制：伪造 DS（全零 digest）必须被拒绝 → 证明 DNSSEC 验证在真实工作而非摆设
printf '. IN DS 20326 8 2 0000000000000000000000000000000000000000000000000000000000000000\n' > /build/drill-bogus.key
SN=$(timeout 60 /build/drill.static -S -k /build/drill-bogus.key example.com @1.1.1.1 2>&1) || true
if echo "$SN" | grep -q "Chase successful"; then
  bad "负控制失败：伪锚定也被判成功（验证未生效）"
else
  NF=$(echo "$SN" | grep -o "Chase failed." | head -1 || true)
  ok "负控制：伪锚定被拒绝（$NF）"
fi

say "DRILL-SUMMARY: FAIL=$FAILS ；产物："
sha256sum /build/drill.static | tee -a "$E"
ls -l /build/drill.static | tee -a "$E"
[ "$FAILS" = 0 ] || exit 1
exit 0
