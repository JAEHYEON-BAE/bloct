# Regression checks

## New block model (F5)

Use Node.js 22.18 or later. Install the locked development dependencies once:

```sh
cd Editor
npm ci
cd ..
sh Tests/run-block-model.sh
```

The runner checks TypeScript, executes the headless ProseMirror/import tests, and
builds `Editor/dist/blocks.js`, shared `math.js`/`math.css`, offline fonts and
license notices for Safari 17/WKWebView. Native runners require these built assets. Xcode bundles these resources for Aa, the sole editing mode.
Aa off is read-only; the old Edit state and block textarea path are removed. `Editor/test/importer.test.ts` covers B01–B09 and B12, including
the existing #16 policy fixture and exact UTF-16 source offsets.
`Editor/test/session.test.ts` covers B10/B11 and source-preserving command/history
round trips, cursor/ID restoration, snapshot acknowledgements and fail-closed
unsupported transformations. These results do not cover native Save, real IME,
clipboard or GUI acceptance. Current evidence is linked from F5 in
[IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md).

After building the bundle, macOS users can check it in an isolated background
WKWebView under nonce CSP with file and inline HTML boot paths:

```sh
sh Tests/run-block-model-webkit.sh
```

This requires permission to launch WebKit processes outside a restrictive sandbox.
Without options it checks engine/serializer execution (18 checks). Add `--visual`
to mount the actual EditorView in both file and inline WKWebViews and test typing
rules, H1–H6/quote/list/task/code placeholders, all 16 menu formats, inline marks,
Enter/exit behavior, cursor placement, plain Unicode/multiline paste, empty task
round trips, search, protected source, engine history and snapshot acknowledgements,
plus attached matrix delimiters, display mode, formula-surface editing and Undo.
The 256 visual checks simulate DOM events/engine text handlers, including formula
click/keyboard activation, Read/freeze guards, drag suppression and pointer CSS, formatted inline-code import/edit/Undo and literal typing guards, inline-code termination, input-rule Undo caret
restoration and unsaved handoff/freeze/baseline restoration. Dollar tests cover
empty/unclosed text, a completed block equation, Enter/Shift-Enter multiline drafts,
block boundaries, code marks, incomplete snapshot reimport and conversion Undo.
They do not verify native physical-pointer hover or continuous dwell. Synthetic composition
is a guard test, not real Korean IME acceptance. It uses temporary files and does
not open or replace the installed Bloct app.

```sh
sh Tests/run-block-model-webkit.sh --visual
sh Tests/run-visual-native.sh
```

The visual native harness hosts the complete production ContentView with the
Aa selected. Its 40 checks cover separate documents, dirty state
without autosave, native/engine Undo/Redo and mode-boundary checkpoints, fixed Save snapshots and
later changes, save failure/retry, clean external reload, Don't Save, Save-and-close
and preview cleanup, including close before a queued dirty notification arrives.
It also checks dirty mode roundtrips, read-only mutation/bridge/Undo blocking, carried saved baseline,
checkpoint Undo/Redo, exhausted Undo preserving Redo, and the same native WebView,
page URL and JavaScript document across mode changes. Four checks start in the default
reading state and verify first-Aa Save, later input and Undo against its saved baseline.
It also checks Save after Aa off, clean reentry after that Save, and reading the
latest clean disk version before enabling Aa. The harness waits for the
real Save/switch busy flags before invoking the mode action, matching the toolbar.
Temporary source copies expose actions, pause disk writes
and capture errors/close warnings; NSDocument revert/close are controlled. First-save panels,
conflict buttons, permission dialogs, real clipboard/IME, PDF, accessibility and
performance require separate validation. CUA evidence and current limitations are
linked in F5. All harnesses leave the installed app untouched.

`sh Tests/run-webkit.sh` also runs [EditorSwitchLayout.js](EditorSwitchLayout.js):
51 renderer/security/math/new-document/layout checks at 900/640px with TOC on/off.
It compares common block geometry and fonts, visible heading offset by toolbar height,
source/page identity and repeated roundtrip drift. Intermediate coordinates use a
16ms timer because offscreen WebKit suspends rAF; this is not painted-frame video. The same runner also executes
[EditorAppearance.js](EditorAppearance.js): 864 appearance/interaction checks across
15 element groups at 900/640px, light/dark, 100/125% page zoom and TOC on/off.
It checks checkboxes, nested/ordered lists, headings, inline styles and whitespace,
code, quotes, aligned/striped tables, rules, block/inline/sized/captioned images,
and sanitized read-only source previews. Element geometry uses 0.1 CSS px tolerance;
word Range edges allow 1px (width 1.25px) for WebKit collapsed-space rounding.
Image editing/Undo/snapshots, blank clicks after images and inert author inputs are
also exercised. Set `BLOCT_APPEARANCE_SNAPSHOTS=/absolute/path/prefix` to save
optional before/after paragraph PNG crops; these are not a pixel-identity assertion.


## Current app regression checks

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
real WKWebViews. The shared bundled KaTeX renders offline. The state-space fixture plus a math
heading checks 11 equations across Markdown/visual modes: exact TeX/display mode,
loaded font family/size and glyph geometry within 0.1 CSS pixels. Missing-runtime
fallback is simulated explicitly; the MathML/SVG sanitizer fixture is also checked.
It covers sanitizer behavior, placeholder collisions, CSP enforcement, native
bridge callbacks, navigation blocking, image URLs and actual local image loading,
and new-document inline HTML loading. It requires permission to launch WebKit
processes and Swift compiler plugins; run outside a restrictive sandbox.

Interactive Save panels are not covered. Both modes use the same offline assets;
there is no KaTeX CDN dependency.

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
- Overlapping initial updates: same-loop and delayed text changes, new/file/read-only
  documents, source relocation, document generation and latest edit/TOC state.
  Real navigation identities are used to inject stale/duplicate completion and failure
  callbacks, retry a failed bootstrap, and close while loading. These callback-order
  checks are controlled tests, not a reproduction of every runtime I/O failure.
- Page suites in `Tests/js`, run inside a hosted page that includes the scripts
  injected on `didFinish`:
  - `aa-editing.js`: ten source types, read-only clicks/typing, absence of old
    edit APIs, one Aa engine, unsaved handoff/reentry, and unapplied property-dialog
    drafts blocking exit until Apply/Cancel.
  - `aa-task-lists.js`: styled disabled reading checkboxes, Aa-only mutations,
    exact marker changes and Undo across duplicates/nesting/quotes/CRLF/empty tasks,
    and inert author HTML inputs.
  - `sanitizer.js`: further attack patterns, legitimate Markdown/HTML that must
    survive sanitizing, KaTeX fonts and CSP violations.

Every file in `Tests/js` returns `JSON.stringify({ results: [{ name, pass, detail, skip }] })`.
Missing bundled KaTeX is a test failure; math checks do not depend on a CDN.

Known defects are listed in `knownFailures` at the top of `HostedRegression.swift`
together with their [BUG_FIXES.md](../BUG_FIXES.md) item. They print `XFAIL` and do not fail the run.
If one passes, the run fails with `XPASS` so the entry is removed after the fix.
No expected failures are currently listed. The two former #20 initial-load failures
now run as ordinary passing checks.

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

```sh
sh Tests/run-task-lists.sh
```

This command now delegates to the 40-check Aa native harness described above.
The retired 17-check legacy task bridge/textarea harness is preserved in Git history
and historical logs. It no longer represents the current Aa-only editing contract.
Hosted task checks exercise the same read-only and Aa-only UI behavior separately.

For CUA GUI sessions, treat Quit as the end of the app handle's lifetime. Do not
chain `app.getAXState()` after quitting or reactivate that handle while the process
is exiting. Use the native app menu for Quit and check global inventory; confirm the actual
process exit when inventory is ambiguous. Obtain a fresh explicit-path handle only
when another run is needed. See [bug 26](../BUG_FIXES.md#26-gui-테스트-중-finder-bloct-is-not-open-anymore)
for observed LaunchServices `-600` reopen errors and the remaining GUI verification.
