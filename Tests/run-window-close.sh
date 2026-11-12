#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. Tests/lib/harness.sh
harness_output bloct-window-close
harness_swiftc Sources/Bloct/Window/CloseProxy.swift Tests/Native/WindowCloseRegression.swift \
    -o "$output_dir/window-close-regression"
"$output_dir/window-close-regression"
