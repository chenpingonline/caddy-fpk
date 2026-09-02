#!/usr/bin/env bash
set -euo pipefail

# Build the FnProxy Nginx core from the official Nginx source archive.
# The build is native: x86 must be built on x86_64; arm64 on AArch64.
VERSION="${NGINX_VERSION:-1.30.4}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-auto}"
WORK="${WORK_DIR:-/tmp/fnproxy-nginx-build}"

host="$(uname -m)"
case "$TARGET" in
  auto)
    case "$host" in
      x86_64|amd64) TARGET="x86" ;;
      aarch64|arm64) TARGET="arm64" ;;
      *) echo "Unsupported build host architecture: $host" >&2; exit 2 ;;
    esac
    ;;
  x86|x86_64|amd64) TARGET="x86" ;;
  arm|arm64|aarch64) TARGET="arm64" ;;
  *) echo "Usage: $0 [x86|arm64]" >&2; exit 2 ;;
esac

case "$TARGET" in
  x86)
    [[ "$host" == "x86_64" || "$host" == "amd64" ]] || {
      echo "x86 Nginx must be built natively on x86_64; current host is $host" >&2
      exit 1
    }
    OUT_DIR="$ROOT/third_party/nginx/x86_64"
    ;;
  arm64)
    [[ "$host" == "aarch64" || "$host" == "arm64" ]] || {
      echo "ARM64 Nginx must be built natively on AArch64; current host is $host" >&2
      exit 1
    }
    OUT_DIR="$ROOT/third_party/nginx/arm64"
    ;;
esac

command -v sudo >/dev/null || { echo "sudo is required" >&2; exit 1; }
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential ca-certificates curl libpcre2-dev libssl-dev zlib1g-dev

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT_DIR"
cd "$WORK"
curl -fsSLO "https://nginx.org/download/nginx-${VERSION}.tar.gz"
tar -xzf "nginx-${VERSION}.tar.gz"
cd "nginx-${VERSION}"

./configure \
  --prefix=.. \
  --conf-path=nginx.conf \
  --pid-path=run/nginx.pid \
  --lock-path=run/nginx.lock \
  --http-log-path=logs/access.log \
  --error-log-path=logs/error.log \
  --http-client-body-temp-path=temp/body \
  --http-proxy-temp-path=temp/proxy \
  --http-fastcgi-temp-path=temp/fastcgi \
  --http-scgi-temp-path=temp/scgi \
  --http-uwsgi-temp-path=temp/uwsgi \
  --with-pcre-jit \
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_realip_module \
  --with-http_stub_status_module \
  --with-http_auth_request_module \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module

make -j"$(nproc)"
strip objs/nginx
install -m 755 objs/nginx "$OUT_DIR/nginx"
install -m 644 conf/mime.types "$ROOT/third_party/nginx/mime.types"

"$OUT_DIR/nginx" -v
sha256sum "$OUT_DIR/nginx"
