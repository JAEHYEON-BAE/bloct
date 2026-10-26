#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-task-tests.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
app_dir="$output_dir/TaskListRegression.app/Contents"
mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
cp Sources/Bloct/task-lists.js Sources/Bloct/marked.min.js Sources/Bloct/purify.min.js Sources/Bloct/style.css "$app_dir/Resources/"
python3 - "$output_dir" <<'PY'
from pathlib import Path
import sys
out = Path(sys.argv[1])
source = Path('Sources/Bloct/ContentView.swift').read_text()
needle = 'var body: some View {\n        MarkdownWebView('
assert source.count(needle) == 1
source = source.replace(needle, '''var body: some View {
        let _ = TaskListProbe.attach(sourceURL, docState, { saveDocument() }, { saveAndClose() }, { discardAndClose() })
        MarkdownWebView(''')
source = source.replace('NSApp.presentError(', 'TaskListProbe.presentError(')
(out / 'ContentView.swift').write_text(source)
source = Path('Sources/Bloct/DocumentDisk.swift').read_text()
needle = 'static func saveAsync(_ text: String, to url: URL, replacing expected: String) async throws {\n'
assert source.count(needle) == 1
source = source.replace(needle, needle + '        await TaskListProbe.beforeSave()\n')
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
    Tests/TaskListRegression.swift -o "$app_dir/MacOS/TaskListRegression"
"$app_dir/MacOS/TaskListRegression"
