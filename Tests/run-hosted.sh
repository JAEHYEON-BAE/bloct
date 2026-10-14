#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-hosted-tests.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
app_dir="$output_dir/HostedRegression.app/Contents"
mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
cp Sources/Bloct/marked.min.js Sources/Bloct/purify.min.js Sources/Bloct/style.css "$app_dir/Resources/"
# Keep the production commands/delegate, substituting only the test entry point.
sed '/^@main$/d' Sources/Bloct/BloctApp.swift > "$output_dir/BloctApp.swift"
set --
for source in Sources/Bloct/*.swift; do
    case "$source" in */BloctApp.swift) ;; *) set -- "$@" "$source" ;; esac
done
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path /private/tmp/bloct-regression-module-cache \
    "$@" "$output_dir/BloctApp.swift" Tests/HostedRegression.swift \
    -o "$app_dir/MacOS/HostedRegression"
"$app_dir/MacOS/HostedRegression" "$(pwd)/Tests/js"
