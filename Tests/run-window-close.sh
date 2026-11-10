#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-window-close.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path /private/tmp/bloct-regression-module-cache \
    Sources/Bloct/WindowCloseProxy.swift Tests/WindowCloseRegression.swift \
    -o "$output_dir/window-close-regression"
"$output_dir/window-close-regression"
