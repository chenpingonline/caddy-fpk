#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="0.1.0"
TARGET="${1:-all}"

case "$TARGET" in
  x86) "$ROOT/scripts/build.sh" x86 ;;
  arm|arm64) "$ROOT/scripts/build.sh" arm64 ;;
  all)
    "$ROOT/scripts/build.sh" x86
    "$ROOT/scripts/build.sh" arm64
    ;;
  *) echo "Usage: $0 [x86|arm64|all]" >&2; exit 2 ;;
esac

if [[ "$TARGET" == "x86" || "$TARGET" == "all" ]]; then
  "$ROOT/tests/integration.sh"
  "$ROOT/tests/fpk-lifecycle.sh" "$ROOT/dist/fnproxy-${VERSION}-x86.fpk"
fi

SOURCE_STAGE="$ROOT/.build/FnProxy-${VERSION}-source"
rm -rf "$SOURCE_STAGE"
mkdir -p "$SOURCE_STAGE"
rsync -a \
  --exclude '.build/' --exclude 'dist/' --exclude '.fnproxy-dev/' \
  --exclude 'fnos/app/bin/fnproxy-server' --exclude 'fnos/app/bin/nginx' \
  "$ROOT/" "$SOURCE_STAGE/"
(cd "$ROOT/.build" && zip -qr "$ROOT/dist/FnProxy-${VERSION}-source.zip" "FnProxy-${VERSION}-source")

(cd "$ROOT/dist" && sha256sum fnproxy-${VERSION}-*.fpk FnProxy-${VERSION}-source.zip > SHA256SUMS.txt)
echo "Release artifacts created in $ROOT/dist"
