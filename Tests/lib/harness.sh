# Shared steps of the Tests/run-*.sh runners. Source it from the repository
# root: `. Tests/lib/harness.sh`.

# A temporary directory, removed on exit: $output_dir.
harness_output() {
    output_dir=$(mktemp -d "${TMPDIR:-/tmp}/$1.XXXXXX")
    trap 'rm -rf "$output_dir"' EXIT
}

# A minimal app bundle inside $output_dir: $app_dir is its Contents folder.
harness_app() {
    app_dir="$output_dir/$1.app/Contents"
    mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
}

# The page template, its scripts and styles, as the app bundles them. The
# Editor/dist files come from `npm run build` in Editor/.
harness_page_resources() {
    cp Sources/Bloct/Resources/Web/page.html Sources/Bloct/Resources/Web/style.css \
        Sources/Bloct/Resources/Vendor/marked.min.js Sources/Bloct/Resources/Vendor/purify.min.js \
        Editor/dist/host.js Editor/dist/blocks.js Editor/dist/visual.css \
        Editor/dist/math.js Editor/dist/math.css Editor/dist/editor-licenses.txt \
        "$app_dir/Resources/"
}

# The app's Swift sources, one per line, without the files named in "$@"
# (base names). Runners pass instrumented copies of those instead.
harness_sources() {
    find Sources/Bloct -name '*.swift' | sort | while read -r source; do
        skip=
        for name in "$@"; do [ "$(basename "$source")" = "$name" ] && skip=1; done
        [ -n "$skip" ] || echo "$source"
    done
}

# BloctApp.swift without @main, so a test can provide the entry point.
harness_app_without_main() {
    sed '/^@main$/d' Sources/Bloct/App/BloctApp.swift > "$1"
}

harness_swiftc() {
    xcrun swiftc -swift-version 6 -parse-as-library \
        -module-cache-path /private/tmp/bloct-regression-module-cache "$@"
}
