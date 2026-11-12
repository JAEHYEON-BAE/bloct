#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. Tests/lib/harness.sh
harness_output bloct-webkit-tests
harness_app Regression
harness_page_resources
# Keep the production commands/delegate, substituting only the test entry point.
harness_app_without_main "$output_dir/BloctApp.swift"
# shellcheck disable=SC2046
harness_swiftc $(harness_sources BloctApp.swift) "$output_dir/BloctApp.swift" Tests/Native/WebKitRegression.swift \
    -o "$app_dir/MacOS/Regression"
"$app_dir/MacOS/Regression" "$PWD/Tests/fixtures/f5-state-space-math.md" "$PWD/Tests/Page/EditorSwitchLayout.js" "$PWD/Tests/Page/EditorAppearance.js"
