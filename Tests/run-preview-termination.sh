#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-preview-termination.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path /private/tmp/bloct-regression-module-cache \
    Sources/Bloct/PreviewFiles.swift Tests/PreviewTerminationRegression.swift \
    -o "$output_dir/preview-termination-regression"
"$output_dir/preview-termination-regression"
