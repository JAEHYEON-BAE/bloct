#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. Tests/lib/harness.sh
harness_output bloct-visual-native
harness_app VisualEditorNative
harness_page_resources
python3 - "$output_dir" <<'PY'
from pathlib import Path
import sys
out=Path(sys.argv[1])
s=Path('Sources/Bloct/Window/ContentView.swift').read_text()
s=s.replace('@State private var visualEditing = false', '@State private var visualEditing = true')
s=s.replace('_originalText = State(initialValue: text)', '_originalText = State(initialValue: text)\n        _visualEditing = State(initialValue: fileURL?.lastPathComponent != "legacy-start.md")')
needle='var body: some View {\n        MarkdownWebView('
assert s.count(needle)==1
s=s.replace(needle,'''var body: some View {
        let _ = VisualProbe.attach(sourceURL, docState, { saveDocument() }, { saveAndClose() }, { discardAndClose() }, { replayEdit(redo: false) }, { replayEdit(redo: true) }, { requestVisualClose() }, { switchEditor() }, { !isSaving && !isSwitchingEditor })
        MarkdownWebView(''')
s=s.replace('NSApp.presentError(', 'VisualProbe.presentError(')
s=s.replace('self.showCloseWarning = true', 'VisualProbe.closeWarnings += 1')
s=s.replace('showCloseWarning = true', 'VisualProbe.closeWarnings += 1')
(out/'ContentView.swift').write_text(s)
s=Path('Sources/Bloct/Document/DocumentDisk.swift').read_text()
needle='static func saveAsync(_ text: String, to url: URL, replacing expected: String) async throws {\n'
assert s.count(needle)==1
s=s.replace(needle,needle+'        await VisualProbe.beforeSave()\n')
(out/'DocumentDisk.swift').write_text(s)
(out/'BloctApp.swift').write_text(Path('Sources/Bloct/App/BloctApp.swift').read_text().replace('@main\n',''))
PY
# shellcheck disable=SC2046
harness_swiftc $(harness_sources BloctApp.swift ContentView.swift DocumentDisk.swift) \
    "$output_dir/BloctApp.swift" "$output_dir/ContentView.swift" "$output_dir/DocumentDisk.swift" \
    Tests/Native/VisualEditorNative.swift -o "$app_dir/MacOS/VisualEditorNative"
"$app_dir/MacOS/VisualEditorNative"
