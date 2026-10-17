#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-tests.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path "$output_dir/module-cache" \
    Sources/Bloct/MarkdownDocument.swift Sources/Bloct/DocumentState.swift \
    Sources/Bloct/DocumentDisk.swift Sources/Bloct/DocumentSaveOperation.swift Sources/Bloct/PreviewFiles.swift \
    Tests/NativeRegression.swift -o "$output_dir/native-regression"
"$output_dir/native-regression"
