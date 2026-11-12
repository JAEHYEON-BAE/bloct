#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. Tests/lib/harness.sh
harness_output bloct-hosted-tests
harness_app HostedRegression
harness_page_resources
# Keep the production commands/delegate, substituting only the test entry point.
harness_app_without_main "$output_dir/BloctApp.swift"
# shellcheck disable=SC2046
harness_swiftc $(harness_sources BloctApp.swift) "$output_dir/BloctApp.swift" Tests/Native/HostedRegression.swift \
    -o "$app_dir/MacOS/HostedRegression"
"$app_dir/MacOS/HostedRegression" "$(pwd)/Tests/Page/hosted"
