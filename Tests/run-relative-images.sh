#!/bin/sh
# Focused image regression. Exits 1 on a failed load or isolation expectation.
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-relative-image-tests.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
fixture_dir=${1:-"$output_dir/fixtures"}
mkdir -p "$fixture_dir"
python3 - "$fixture_dir" <<'PY'
import struct, sys, zlib
from pathlib import Path
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
w, h = 96, 24
raw = b''.join(b'\x00' + bytes([36, 180, 92]) * w for _ in range(h))
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
(Path(sys.argv[1]) / 'pixel.png').write_bytes(png)
PY
app_dir="$output_dir/RelativeImageRegression.app/Contents"
mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
cp Sources/Bloct/task-lists.js Sources/Bloct/marked.min.js Sources/Bloct/purify.min.js Sources/Bloct/style.css "$app_dir/Resources/"
sed '/^@main$/d' Sources/Bloct/BloctApp.swift > "$output_dir/BloctApp.swift"
set --
for source in Sources/Bloct/*.swift; do
    case "$source" in */BloctApp.swift) ;; *) set -- "$@" "$source" ;; esac
done
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path /private/tmp/bloct-regression-module-cache \
    "$@" "$output_dir/BloctApp.swift" Tests/RelativeImageRegression.swift \
    -o "$app_dir/MacOS/RelativeImageRegression"
"$app_dir/MacOS/RelativeImageRegression" "$fixture_dir"
