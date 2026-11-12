#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. Tests/lib/harness.sh
harness_output bloct-menu-tests
harness_app MenuPollingRegression
harness_page_resources
# Instrument temporary source copies, leaving production code free of test hooks.
python3 - "$output_dir" <<'PY'
from pathlib import Path
import sys
out = Path(sys.argv[1])
source = Path('Sources/Bloct/Window/ContentView.swift').read_text()
needle = 'var body: some View {\n        MarkdownWebView('
assert source.count(needle) == 1
source = source.replace(needle, 'var body: some View {\n        let _ = MenuPollingProbe.recordBody()\n        MarkdownWebView(')
(out / 'ContentView.swift').write_text(source)
source = Path('Sources/Bloct/Document/DocumentDisk.swift').read_text()
needle = 'static func readAsync(_ url: URL) async throws -> String {\n'
assert source.count(needle) == 1
source = source.replace(needle, needle + '        await MainActor.run { MenuPollingProbe.reads += 1 }\n        return ')
(out / 'DocumentDisk.swift').write_text(source)
(out / 'BloctApp.swift').write_text(Path('Sources/Bloct/App/BloctApp.swift').read_text().replace('@main\n', ''))
PY
# shellcheck disable=SC2046
harness_swiftc $(harness_sources BloctApp.swift ContentView.swift DocumentDisk.swift) \
    "$output_dir/BloctApp.swift" "$output_dir/ContentView.swift" "$output_dir/DocumentDisk.swift" \
    Tests/Native/MenuPollingRegression.swift -o "$app_dir/MacOS/MenuPollingRegression"
"$app_dir/MacOS/MenuPollingRegression"
