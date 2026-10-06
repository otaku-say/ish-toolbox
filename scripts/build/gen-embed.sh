#!/bin/sh
# gen-embed.sh —— 生成两个内嵌头（在 LibreSSL 源码根目录内运行；Alpine/busybox sh 兼容）
#   crypto/x509/tb-embed-ca.h    ← CA bundle（默认 /etc/ssl/certs/ca-certificates.crt）
#   apps/openssl/tb-embed-conf.h ← 最小配置（默认 /build/libressl-min.cnf）
# 由 curl.sh 的 inner 在打完 libressl-ishfix.patch 后调用；生成式（不随补丁分发大文件）。
set -eu
CA=${1:-/etc/ssl/certs/ca-certificates.crt}
MIN=${2:-/build/libressl-min.cnf}

emit() { # <标识符> <输入> <输出>
  {
    echo "/* 自动生成（otaku-say/ish-toolbox）：勿手改 */"
    echo "static const char $1[] ="
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/$/\\n"/' "$2" | sed 's/^/"/'
    echo ";"
  } > "$3"
}

emit tb_ca_pem "$CA" crypto/x509/tb-embed-ca.h
emit tb_minconf "$MIN" apps/openssl/tb-embed-conf.h
echo "gen-embed: tb-embed-ca.h ($(wc -l < "$CA") 行), tb-embed-conf.h ($(wc -l < "$MIN") 行)"
