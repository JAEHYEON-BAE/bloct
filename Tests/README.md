# Regression checks

Run from the repository root on macOS with Xcode installed:

```sh
sh Tests/run-native.sh
```

The native harness compiles production state, save callback, and preview-file code.
It verifies that two block commits take exactly two Undo/Redo steps, drafts do not
reach the FileDocument binding until Save, in-flight snapshots remain isolated,
cancelled snapshots can roll back without losing the draft, and 25 discard cycles
never publish abandoned edits. It also checks idempotent staging after a view-update
boundary, callback lifetime and success/failure propagation using a controlled
NSDocument, and real temporary-file creation/cleanup without overwriting an existing
`.mv_preview.html`.

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

```sh
sh Tests/run-menu-polling.sh
```

The #25 harness hosts the complete production `ContentView` and instruments temporary
source copies to count body evaluations and coordinated reads. It checks that idle
polling keeps reading without rebuilding focused commands, pauses in event-tracking
mode, resumes external reloads, preserves drafts, and stops/cleans previews on close.
It requires the same Swift compiler-plugin and WebKit permissions as the other GUI
harnesses. These counters cover the menu invalidation path; continuous menu visuals
and real pointer dwell still need a separate GUI check.

```sh
sh Tests/run-hosted.sh
```

The hosted harness puts the production `MarkdownWebView` in an `NSHostingView`, so
SwiftUI drives the real `makeNSView` / `updateNSView` / `dismantleNSView`. It covers:

- Document locations: Korean names with spaces, `#` `%` and tilde, NFD-normalized
  names, a folder opened through a symlink, a read-only folder (the
  `loadHTMLString` fallback with the image-only scheme loader) and a new document.
  For each it checks page load,
  editor commits reaching Swift, relative image loading, and creation and removal
  of the per-document preview file next to an existing `.mv_preview.html`.
- Navigation policy: relative links, script navigation, reload and history must
  not replace the page that owns the bridge. External http(s) links are left out
  because allowing them would open a real browser.
- Overlapping initial loads: the document text changes before the first load
  finishes.
- Page suites in `Tests/js`, run inside a hosted page that includes the scripts
  injected on `didFinish`:
  - `block-editing.js`: block editing, Swift re-render while editing, keyboard
    navigation, dirty messages, math and offline fallback, search, style tokens,
    copy as Markdown.
  - `sanitizer.js`: further attack patterns, legitimate Markdown/HTML that must
    survive sanitizing, KaTeX fonts and CSP violations.

Every file in `Tests/js` returns `JSON.stringify({ results: [{ name, pass, detail, skip }] })`.
Checks that need the KaTeX CDN are skipped when it is unreachable.

Known defects are listed in `knownFailures` at the top of `HostedRegression.swift`
together with their [BUG_FIXES.md](../BUG_FIXES.md) item. They print `XFAIL` and do not fail the run.
If one passes, the run fails with `XPASS` so the entry is removed after the fix.
Currently listed: overlapping initial loads in the same run loop (#20).

Implementation summaries and feature plans are maintained in
[IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md).
Archived logs retain their original `CODE_REVIEW #N` labels and former document
name; these refer to the same numbered items in `BUG_FIXES.md`. Raw logs are
preserved without rewriting historical output.

```sh
sh Tests/run-relative-images.sh
```

The focused #24 regression loads 54 PNG images across parent paths, Korean/spaced
folders and a read-only document folder, with three fresh views per case. It also
checks JPEG/SVG, encoded filenames, image editing and reopening, document resource
isolation, copy preserving the original image URL, rejected non-image resources,
and loader invalidation. It uses actual image decoding, with no XFAIL or SKIP.
An optional directory argument retains fixtures for manual GUI checks.
