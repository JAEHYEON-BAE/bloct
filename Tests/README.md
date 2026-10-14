# Regression checks

Run from the repository root on macOS with Xcode installed:

```sh
sh Tests/run-native.sh
```

The native harness compiles production state, save callback, and preview-file code.
It verifies Undo/Redo against the FileDocument binding, callback lifetime and
success/failure propagation using a controlled NSDocument, and real temporary-file
creation/cleanup without overwriting an existing `.mv_preview.html`.

It does not drive Save panels, permission dialogs, or multi-window quit flows.
Build the app after `xcodegen generate` to check SwiftUI integration as well.
