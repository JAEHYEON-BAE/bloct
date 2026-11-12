#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. Tests/lib/harness.sh
harness_output bloct-preview-termination
harness_swiftc Sources/Bloct/WebView/PreviewFiles.swift Tests/Native/PreviewTerminationRegression.swift \
    -o "$output_dir/preview-termination-regression"
"$output_dir/preview-termination-regression"
