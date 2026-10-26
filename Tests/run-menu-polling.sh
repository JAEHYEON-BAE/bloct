#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-menu-tests.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
app_dir="$output_dir/MenuPollingRegression.app/Contents"
mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
cp Sources/Bloct/task-lists.js Sources/Bloct/marked.min.js Sources/Bloct/purify.min.js Sources/Bloct/style.css "$app_dir/Resources/"
# Instrument temporary source copies, leaving production code free of test hooks.
python3 - "$output_dir" <<'PY'
from pathlib import Path
import sys
out = Path(sys.argv[1])
source = Path('Sources/Bloct/ContentView.swift').read_text()
needle = 'var body: some View {\n        MarkdownWebView('
assert source.count(needle) == 1
source = source.replace(needle, 'var body: some View {\n        let _ = MenuPollingProbe.recordBody()\n        MarkdownWebView(')
(out / 'ContentView.swift').write_text(source)
source = Path('Sources/Bloct/DocumentDisk.swift').read_text()
needle = 'static func readAsync(_ url: URL) async throws -> String {\n'
assert source.count(needle) == 1
source = source.replace(needle, needle + '        await MainActor.run { MenuPollingProbe.reads += 1 }\n        return ')
(out / 'DocumentDisk.swift').write_text(source)
(out / 'BloctApp.swift').write_text(Path('Sources/Bloct/BloctApp.swift').read_text().replace('@main\n', ''))
PY
set --
for source in Sources/Bloct/*.swift; do
    case "$source" in
        */BloctApp.swift|*/ContentView.swift|*/DocumentDisk.swift) ;;
        *) set -- "$@" "$source" ;;
    esac
done
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path /private/tmp/bloct-regression-module-cache \
    "$@" "$output_dir/BloctApp.swift" "$output_dir/ContentView.swift" "$output_dir/DocumentDisk.swift" \
    Tests/MenuPollingRegression.swift -o "$app_dir/MacOS/MenuPollingRegression"
"$app_dir/MacOS/MenuPollingRegression"
