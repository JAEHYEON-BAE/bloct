#!/bin/sh
# Focused image regression. Exits 1 on a failed load or isolation expectation.
set -eu
cd "$(dirname "$0")/.."
. Tests/lib/harness.sh
harness_output bloct-relative-image-tests
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
harness_app RelativeImageRegression
harness_page_resources
harness_app_without_main "$output_dir/BloctApp.swift"
# shellcheck disable=SC2046
harness_swiftc $(harness_sources BloctApp.swift) "$output_dir/BloctApp.swift" Tests/Native/RelativeImageRegression.swift \
    -o "$app_dir/MacOS/RelativeImageRegression"
"$app_dir/MacOS/RelativeImageRegression" "$fixture_dir"
