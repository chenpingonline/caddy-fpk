#!/usr/bin/env bash
set -euo pipefail

FPK="${1:?Usage: verify-fpk.sh <file.fpk>}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v file >/dev/null || { echo "Missing file" >&2; exit 1; }
command -v strings >/dev/null || { echo "Missing strings" >&2; exit 1; }

tar -xzf "$FPK" -C "$WORK"
for required in app.tgz manifest cmd/main config/privilege config/resource ICON.PNG ICON_256.PNG; do
  [[ -e "$WORK/$required" ]] || { echo "FPK missing $required" >&2; exit 1; }
done

expected="$(awk -F= '$1 ~ /^[[:space:]]*checksum[[:space:]]*$/ {gsub(/[[:space:]]/, "", $2); print $2}' "$WORK/manifest")"
if command -v md5sum >/dev/null; then
  actual="$(md5sum "$WORK/app.tgz" | awk '{print $1}')"
else
  actual="$(md5 -q "$WORK/app.tgz")"
fi
[[ -n "$expected" && "$expected" == "$actual" ]] || { echo "app.tgz MD5 mismatch" >&2; exit 1; }

platform="$(awk -F= '$1 ~ /^[[:space:]]*platform[[:space:]]*$/ {gsub(/[[:space:]]/, "", $2); print $2}' "$WORK/manifest")"
case "$platform" in
  x86) machine='x86-64|X86-64'; host_ok=false; [[ "$(uname -m)" == "x86_64" ]] && host_ok=true ;;
  arm) machine='ARM aarch64|AArch64'; host_ok=false; [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]] && host_ok=true ;;
  *) echo "Unsupported manifest platform: $platform" >&2; exit 1 ;;
esac

mkdir -p "$WORK/app"
tar -xzf "$WORK/app.tgz" -C "$WORK/app"
for required in bin/fnproxy-server bin/nginx etc/mime.types ui/config ui/images/icon_64.png ui/images/icon_256.png; do
  [[ -e "$WORK/app/$required" ]] || { echo "app.tgz missing $required" >&2; exit 1; }
done

file "$WORK/app/bin/fnproxy-server" | grep -Eq "$machine" || { echo "Manager architecture mismatch" >&2; exit 1; }
file "$WORK/app/bin/nginx" | grep -Eq "$machine" || { echo "Nginx architecture mismatch" >&2; exit 1; }
strings "$WORK/app/bin/nginx" | grep -F 'nginx/1.30.4' >/dev/null || { echo "Nginx version mismatch" >&2; exit 1; }
strings "$WORK/app/bin/fnproxy-server" | grep -F 'FnProxy' >/dev/null || { echo "Manager identity string missing" >&2; exit 1; }

if $host_ok; then
  "$WORK/app/bin/fnproxy-server" version | grep -q 'FnProxy 0.1.0' || { echo "Manager version mismatch" >&2; exit 1; }
  LD_LIBRARY_PATH="$WORK/app/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$WORK/app/bin/nginx" -v 2>&1 | grep -q 'nginx/1.30.4' || { echo "Nginx runtime version mismatch" >&2; exit 1; }
fi

python3 - "$WORK" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
json.loads((root/'config/privilege').read_text())
json.loads((root/'config/resource').read_text())
json.loads((root/'app/ui/config').read_text())
manifest = (root/'manifest').read_text()
for key in ('appname', 'version', 'display_name', 'platform', 'checksum'):
    if not any(line.split('=',1)[0].strip() == key for line in manifest.splitlines() if '=' in line):
        raise SystemExit(f'manifest missing {key}')
PY

bash -n "$WORK/cmd/main" "$WORK/cmd/install_callback" "$WORK/cmd/upgrade_callback"
echo "FPK verification passed: $(basename "$FPK")"
