#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="0.1.0"
TARGET="${1:-x86}"
DIST="$ROOT/dist"

case "$TARGET" in
  x86|x86_64|amd64)
    PLATFORM="x86"
    PACKAGE_ARCH="x86"
    GOARCH="amd64"
    NGINX_DIR="$ROOT/third_party/nginx/x86_64"
    EXPECTED_MACHINE='x86-64|X86-64'
    ;;
  arm|arm64|aarch64)
    PLATFORM="arm"
    PACKAGE_ARCH="arm64"
    GOARCH="arm64"
    NGINX_DIR="$ROOT/third_party/nginx/arm64"
    EXPECTED_MACHINE='ARM aarch64|AArch64'
    ;;
  *)
    echo "Usage: $0 <x86|arm64>" >&2
    exit 2
    ;;
esac

BUILD_ROOT="$ROOT/.build/$PACKAGE_ARCH"
STAGE="$BUILD_ROOT/fpk"
APP_STAGE="$BUILD_ROOT/app"
FPK_NAME="fnproxy-${VERSION}-${PACKAGE_ARCH}.fpk"
NGINX_BIN="${FNPROXY_NGINX_BIN:-$NGINX_DIR/nginx}"

command -v go >/dev/null || { echo "Missing Go" >&2; exit 1; }
command -v tar >/dev/null || { echo "Missing tar" >&2; exit 1; }
command -v file >/dev/null || { echo "Missing file" >&2; exit 1; }
command -v strings >/dev/null || { echo "Missing strings" >&2; exit 1; }
[[ -x "$NGINX_BIN" ]] || {
  echo "Missing Nginx executable: $NGINX_BIN" >&2
  echo "Build it first with: ./scripts/build-nginx.sh $PACKAGE_ARCH" >&2
  echo "Or set FNPROXY_NGINX_BIN=/path/to/nginx" >&2
  exit 1
}

rm -rf "$BUILD_ROOT"
mkdir -p "$DIST" "$STAGE" "$APP_STAGE/bin"

printf '[1/8] Running Go tests\n'
(cd "$ROOT" && go test ./...)

printf '[2/8] Building Linux/%s manager\n' "$GOARCH"
CGO_ENABLED=0 GOOS=linux GOARCH="$GOARCH" go build \
  -trimpath -buildvcs=false -ldflags='-s -w' \
  -o "$APP_STAGE/bin/fnproxy-server" "$ROOT"

printf '[3/8] Staging Nginx and application assets\n'
cp -a "$ROOT/fnos/app/." "$APP_STAGE/"
install -m 755 "$NGINX_BIN" "$APP_STAGE/bin/nginx"
chmod 755 "$APP_STAGE/bin/fnproxy-server"
install -m 644 "$ROOT/third_party/nginx/mime.types" "$APP_STAGE/etc/mime.types"

printf '[4/8] Checking executable architectures\n'
file "$APP_STAGE/bin/fnproxy-server" | grep -Eq "$EXPECTED_MACHINE" || {
  echo "Manager architecture mismatch: $(file "$APP_STAGE/bin/fnproxy-server")" >&2
  exit 1
}
file "$APP_STAGE/bin/nginx" | grep -Eq "$EXPECTED_MACHINE" || {
  echo "Nginx architecture mismatch: $(file "$APP_STAGE/bin/nginx")" >&2
  exit 1
}
strings "$APP_STAGE/bin/nginx" | grep -F 'nginx/1.30.4' >/dev/null || {
  echo "Nginx version string is not 1.30.4" >&2
  exit 1
}

printf '[5/8] Creating app.tgz\n'
tar --sort=name --mtime='UTC 2026-09-01 00:00:00' --owner=0 --group=0 --numeric-owner \
  -czf "$STAGE/app.tgz" -C "$APP_STAGE" .

if command -v md5sum >/dev/null; then
  app_md5="$(md5sum "$STAGE/app.tgz" | awk '{print $1}')"
else
  app_md5="$(md5 -q "$STAGE/app.tgz")"
fi

printf '[6/8] Assembling FPK metadata\n'
cp -a "$ROOT/fnos/cmd" "$ROOT/fnos/config" "$ROOT/fnos/wizard" "$STAGE/"
cp "$ROOT/fnos/ICON.PNG" "$ROOT/fnos/ICON_256.PNG" "$STAGE/"
cp "$ROOT/fnos/LICENSE" "$ROOT/fnos/NOTICE" "$ROOT/fnos/THIRD_PARTY_LICENSES.md" "$ROOT/fnos/NGINX_LICENSE" "$STAGE/"
sed -E "s/^[[:space:]]*platform[[:space:]]*=.*/platform                   = ${PLATFORM}/" "$ROOT/fnos/manifest" \
  | grep -v '^[[:space:]]*checksum[[:space:]]*=' > "$STAGE/manifest"
printf 'checksum                   = %s\n' "$app_md5" >> "$STAGE/manifest"
chmod 755 "$STAGE/cmd/"*

if [[ "$PLATFORM" == "arm" ]]; then
  cp "$ROOT/third_party/nginx/arm64/NGINX_ARM64_SHA1.txt" "$STAGE/"
  cp "$ROOT/third_party/nginx/arm64/NGINX_ARM64_SOURCES.txt" "$STAGE/"
fi

printf '[7/8] Creating %s\n' "$FPK_NAME"
tar --sort=name --mtime='UTC 2026-09-01 00:00:00' --owner=0 --group=0 --numeric-owner \
  -czf "$DIST/$FPK_NAME" -C "$STAGE" .

printf '[8/8] Verifying FPK\n'
"$ROOT/scripts/verify-fpk.sh" "$DIST/$FPK_NAME"
sha256sum "$DIST/$FPK_NAME" > "$DIST/${FPK_NAME}.sha256"
printf 'Done: %s\n' "$DIST/$FPK_NAME"
