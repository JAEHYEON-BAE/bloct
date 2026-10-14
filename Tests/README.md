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

```sh
sh Tests/run-webkit.sh
```

The WebKit harness builds a temporary app-shaped test bundle and compiles the
production sources with the test entry point. It loads the production HTML in
real WKWebViews. The two remote KaTeX resources are omitted for deterministic
offline tests; math fallback and a KaTeX-shaped MathML/SVG fixture are checked.
It covers sanitizer behavior, placeholder collisions, CSP enforcement, native
bridge callbacks, navigation blocking, image URLs and actual local image loading,
and new-document inline HTML loading. It requires permission to launch WebKit
processes and Swift compiler plugins; run outside a restrictive sandbox.

Live KaTeX CDN rendering and interactive Save panels are not covered.
