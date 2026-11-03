#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-block-webkit.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
app_dir="$output_dir/BlockModel.app/Contents"
mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
cp Editor/dist/blocks.js "$app_dir/Resources/"
cat > "$app_dir/Resources/index.html" <<'HTML'
<!doctype html><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-block-model-test'">
<script nonce="block-model-test" src="blocks.js"></script><body>Block model test</body>
HTML
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path /private/tmp/bloct-regression-module-cache \
    Tests/BlockModelWebKit.swift -o "$app_dir/MacOS/BlockModel"
"$app_dir/MacOS/BlockModel" "$app_dir/Resources"
