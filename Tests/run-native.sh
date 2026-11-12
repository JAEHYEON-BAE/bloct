#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. Tests/lib/harness.sh
harness_output bloct-tests
harness_swiftc \
    Sources/Bloct/Document/MarkdownDocument.swift Sources/Bloct/Document/DocumentWriteProtection.swift \
    Sources/Bloct/Document/DocumentState.swift Sources/Bloct/Document/DocumentDisk.swift \
    Sources/Bloct/Document/DocumentSaveOperation.swift Sources/Bloct/Document/StagedDocumentSave.swift \
    Sources/Bloct/WebView/PreviewFiles.swift \
    Tests/Native/NativeRegression.swift -o "$output_dir/native-regression"
"$output_dir/native-regression"
