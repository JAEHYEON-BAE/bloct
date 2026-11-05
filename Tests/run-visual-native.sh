#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
output_dir=$(mktemp -d "${TMPDIR:-/tmp}/bloct-visual-native.XXXXXX")
trap 'rm -rf "$output_dir"' EXIT
app_dir="$output_dir/VisualEditorNative.app/Contents"
mkdir -p "$app_dir/MacOS" "$app_dir/Resources"
cp Sources/Bloct/task-lists.js Sources/Bloct/marked.min.js Sources/Bloct/purify.min.js Sources/Bloct/style.css "$app_dir/Resources/"
cp Editor/dist/math.js Editor/dist/math.css "$app_dir/Resources/"
cp Editor/dist/blocks.js Editor/dist/visual.css Editor/dist/editor-licenses.txt "$app_dir/Resources/"
python3 - "$output_dir" <<'PY'
from pathlib import Path
import sys
out=Path(sys.argv[1])
s=Path('Sources/Bloct/ContentView.swift').read_text()
s=s.replace('@State private var visualEditing = false', '@State private var visualEditing = true')
needle='var body: some View {\n        MarkdownWebView('
assert s.count(needle)==1
s=s.replace(needle,'''var body: some View {
        let _ = VisualProbe.attach(sourceURL, docState, { saveDocument() }, { saveAndClose() }, { discardAndClose() }, { replayEdit(redo: false) }, { replayEdit(redo: true) }, { requestVisualClose() })
        MarkdownWebView(''')
s=s.replace('NSApp.presentError(', 'VisualProbe.presentError(')
s=s.replace('self.showCloseWarning = true', 'VisualProbe.closeWarnings += 1')
s=s.replace('showCloseWarning = true', 'VisualProbe.closeWarnings += 1')
(out/'ContentView.swift').write_text(s)
s=Path('Sources/Bloct/DocumentDisk.swift').read_text()
needle='static func saveAsync(_ text: String, to url: URL, replacing expected: String) async throws {\n'
assert s.count(needle)==1
s=s.replace(needle,needle+'        await VisualProbe.beforeSave()\n')
(out/'DocumentDisk.swift').write_text(s)
(out/'BloctApp.swift').write_text(Path('Sources/Bloct/BloctApp.swift').read_text().replace('@main\n',''))
PY
set --
for source in Sources/Bloct/*.swift; do
    case "$source" in */BloctApp.swift|*/ContentView.swift|*/DocumentDisk.swift) ;; *) set -- "$@" "$source" ;; esac
done
xcrun swiftc -swift-version 6 -parse-as-library -module-cache-path /private/tmp/bloct-regression-module-cache \
    "$@" "$output_dir/BloctApp.swift" "$output_dir/ContentView.swift" "$output_dir/DocumentDisk.swift" \
    Tests/VisualEditorNative.swift -o "$app_dir/MacOS/VisualEditorNative"
"$app_dir/MacOS/VisualEditorNative"
