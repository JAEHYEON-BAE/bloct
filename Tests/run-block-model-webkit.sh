#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-block-webkit.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
app_dir="$output_dir/BlockModel.app/Contents"
mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
cp Editor/dist/blocks.js Editor/dist/math.js "$app_dir/Resources/"
cp Editor/dist/visual.css "$app_dir/Resources/"
cat > "$app_dir/Resources/index.html" <<'HTML'
<!doctype html><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-block-model-test'; style-src 'unsafe-inline'; font-src data:; img-src data:">
<script nonce="block-model-test" src="math.js"></script>
<script nonce="block-model-test" src="blocks.js"></script><body>Block model test</body>
HTML
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path /private/tmp/bloct-regression-module-cache \
    Tests/Native/BlockModelWebKit.swift -o "$app_dir/MacOS/BlockModel"
if [ "${1:-}" = "--visual" ]; then
    "$app_dir/MacOS/BlockModel" "$app_dir/Resources" "$PWD/Editor/test/dom/visual-editor.js"
else
    "$app_dir/MacOS/BlockModel" "$app_dir/Resources"
fi
