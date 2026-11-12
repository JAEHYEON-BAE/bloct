# Regression checks

## Layout

| Folder | Contents |
|---|---|
| `Tests/run-*.sh` | Runners. Each builds a temporary app-shaped bundle or binary and runs one harness |
| `Tests/lib/harness.sh` | Shared runner steps: temporary output, app bundle, page resources, Swift sources, `swiftc` |
| `Tests/Native/` | Swift harnesses compiled with the production sources |
| `Tests/Page/` | Page suites evaluated in WKWebView; `Page/hosted/` is loaded whole by `run-hosted.sh` |
| `Tests/GUI/` | Computer Use app-session helper and its regression |
| `Tests/fixtures/` | Markdown fixtures shared by the model and WebKit checks |
| `Tests/results/` | Raw evidence, latest two dates only ([AGENTS.md](../AGENTS.md)) |

Editor model/DOM tests live in `Editor/test/unit/` and `Editor/test/dom/`.
Page resources come from `Sources/Bloct/Resources/` and `Editor/dist/` (`npm run build`),
including `host.js`, the page scripts of `Editor/src/host/` joined in order.

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
license notices for Safari 17/WKWebView. Native runners require these built assets.
Production uses `automaticEditing: true`: one EditorView starts read-only, a body
click activates editing at its coordinates, and Esc returns to reading. There is
no editing toggle button or formatting toolbar. The default component configuration retains
manual switching for compatibility harnesses. `Editor/test/unit/importer.test.ts` covers B01–B09 and B12, including
the existing #16 policy fixture and exact UTF-16 source offsets.
`Editor/test/unit/session.test.ts` covers B10/B11 and source-preserving command/history
round trips, cursor/ID restoration, snapshot acknowledgements and fail-closed
unsupported transformations. `Editor/test/unit/serializer.test.ts` pins the written
form of edited blocks: escaping only where a character would start syntax,
nested and overlapping formatting, link and autolink forms, URL-like text and
nested emphasis import. `Editor/test/unit/separators.test.ts` pins where a new pair of neighbouring
blocks is written without a blank line: Enter and type changes, every pair of
block types against what the parser reads back, content that merges a pair,
separators already in the file and the opening Text line.
`Editor/test/unit/serializer-fuzz.test.ts` saves seeded
random inline drafts (3 seeds × 700 rounds) and compares what reads back. It leaves out line breaks in
headings/table cells and link addresses starting with `<`, which Markdown cannot
hold. These results do not cover native Save, real IME,
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
rules, H1–H6/code placeholders and unlabelled empty Text/quote/list/task blocks, all 16 engine formats (with no visible formatting toolbar), inline marks,
Enter/exit behavior, cursor placement, plain Unicode/multiline paste, empty task
round trips, search, protected source, engine history and snapshot acknowledgements,
plus opt-in trailing Text lines with exact EOF/source preservation, typing/Undo/reload/handoff, attached matrix delimiters, display mode, formula-surface editing and Undo.
The 380 visual checks simulate DOM events/engine text handlers, including formula
click/keyboard activation, arrow-selected inline/block math with hover-style highlighting and Enter dialogs, native-selection paint suppression, Read/freeze guards, drag suppression and pointer CSS, formatted inline-code import/edit/Undo and literal typing guards, inline-code termination, bold/italic ending at the closing marker, plain typing right after an inline code span, Mod-e code typing, input-rule Undo caret
restoration, same-line Text boundary joining in both directions across quotes/lists, and unsaved handoff/freeze/baseline restoration. Dollar tests cover
empty/unclosed text, a completed block equation, Enter/Shift-Enter multiline drafts,
block boundaries, code marks, incomplete snapshot reimport and conversion Undo.
Three checks per boot path type URL/address/entity text, bold ending in a space
(Mod-b) and an edit to a formatted paragraph, and compare the saved Markdown exactly.
Heading Return checks cover H1–H6 with Enter/Shift-Enter at the start, middle, end, empty content and a selected prefix, both top-level and quoted, including follow-up Text, Undo and Save/reimport.
They do not verify native physical-pointer hover or continuous dwell. Synthetic composition
is a guard test, not real Korean IME acceptance. It uses temporary files and does
not open or replace the installed Bloct app.

```sh
sh Tests/run-block-model-webkit.sh --visual
sh Tests/run-visual-native.sh
```

The visual native harness hosts the complete production ContentView.
Its 49 checks cover separate documents, dirty state
without autosave, native/engine Undo/Redo and native checkpoints, fixed Save snapshots and
later changes, save failure/retry, clean external reload, Don't Save, Save-and-close
and preview cleanup, including close before a queued dirty notification arrives.
It also checks dirty mode roundtrips, read-only mutation/bridge/Undo blocking, carried saved baseline,
checkpoint Undo/Redo, exhausted Undo preserving Redo, and the same native WebView,
page URL and JavaScript document across focus changes. Default-reading checks
exercise click/Esc requests through the real native bridge and verify the same
EditorView, first Save, later input and Undo against its saved baseline.
It also checks Save after Esc, clean reentry after that Save, and reading the
latest clean disk version before editing. The harness waits for the
real Save/switch busy flags before invoking an action.
Dialog checks cover local Undo/Redo, exhausted history blocking document checkpoints,
draft selection restoration, Apply as one document step, Cancel and fresh history on reopen.
Temporary source copies expose actions, pause disk writes
and capture errors/close warnings; NSDocument revert/close are controlled. First-save panels,
conflict buttons, permission dialogs, real clipboard/IME, PDF, accessibility and
performance require separate validation. CUA evidence and current limitations are
linked in F5. All harnesses leave the installed app untouched.

`sh Tests/run-webkit.sh` also runs [EditorSwitchLayout.js](Page/EditorSwitchLayout.js):
54 renderer/security/math/new-document/layout checks at 900/640px with TOC on/off.
It compares common block geometry and fonts, unchanged visible heading position without a toolbar,
source/page identity and repeated roundtrip drift. Intermediate coordinates use a
16ms timer because offscreen WebKit suspends rAF; this is not painted-frame video. The same runner also executes
[EditorAppearance.js](Page/EditorAppearance.js): 864 appearance/interaction checks across
15 element groups at 900/640px, light/dark, 100/125% page zoom and TOC on/off.
It checks checkboxes, nested/ordered lists, headings, inline styles and whitespace,
code, quotes, aligned/striped tables, rules, block/inline/sized/captioned images,
and sanitized read-only source previews. Element geometry uses 0.1 CSS px tolerance;
word Range edges allow 1px (width 1.25px) for WebKit collapsed-space rounding.
Image editing/Undo/snapshots, blank clicks after images and inert author inputs are
also exercised. Set `BLOCT_APPEARANCE_SNAPSHOTS=/absolute/path/prefix` to save
optional before/after paragraph PNG crops; these are not a pixel-identity assertion.

The same runner loads [ClickFocus.js](Page/ClickFocus.js) with automatic editing enabled:
45 checks cover exact clicked text positions in paragraphs/headings/quotes/lists/tables,
immediate input, persistent EditorView/history/draft, read-only mutation guards,
scrolled and empty documents, end padding, modifier/composition guards, one-click
equation dialogs and task toggles, and toolbar absence. Reading Escape is consumed
without additional mode requests; popup Escape explicitly cancels its draft while
preserving document editing. Composition and modified Escape keep their default
handling. These DOM checks do not detect native warning sounds; the actual-key
AppKit path audit is linked from [bug 46](../BUG_FIXES.md#bug-46). This suite simulates the
native mode acknowledgement; the native harness above covers the actual bridge,
and the Computer Use evidence linked in F5 covers physical input and screenshots.


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
sh Tests/run-window-close.sh
```

The #45 harness checks nine AppKit close-proxy cases: original delegate veto,
unsaved interception, one-shot bypass, live notification forwarding, one willClose
callback, notification removal before a dynamic delegate stops advertising a
selector, and restoration/preservation of delegates on view removal. The old proxy
aborts when a cached window notification outlives its forwarding capability. This
controlled reproduction complements the real Save/Don't Save/Cancel and multi-window
Quit evidence linked from [BUG_FIXES.md #45](../BUG_FIXES.md#bug-45).

```sh
sh Tests/run-preview-termination.sh
```

The #29 harness launches three real AppKit subprocesses without an
applicationWillTerminate cleanup delegate. It checks one/multiple live previews,
Quit cancellation followed by successful Quit, synchronous ownership-based cleanup
before process exit, and preservation of existing legacy and other-session files.
The production preview owner observes the process termination notification directly;
no view teardown or delegate forwarding is required. Real-app evidence is linked in
[BUG_FIXES.md #29](../BUG_FIXES.md#29-앱-메뉴-quit-후-고유-미리보기-파일-잔류).

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
Since 2026-11-12 the runner copies the full page resources like the others; one check
still fails: "draft survives unchanged disk polling" drives the legacy `commitEdit`
message, which the block editor no longer sends. The same failure appears on the
previous commit with resources added (PROJECT_REVIEW.md 4.2, 7.3).

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
- Compatibility page suites in `Tests/Page/hosted`, run with manual mode switching inside
  a hosted page that includes the scripts injected on `didFinish`:
  - `aa-editing.js`: ten source types, read-only clicks/typing, absence of old
    edit APIs, one block editor engine, unsaved handoff/reentry, and unapplied property-dialog
    drafts blocking exit until Apply/Cancel.
  - `aa-task-lists.js`: styled disabled reading checkboxes, mutations only while editing,
    exact marker changes and Undo across duplicates/nesting/quotes/CRLF/empty tasks,
    and inert author HTML inputs.
  - `sanitizer.js`: further attack patterns, legitimate Markdown/HTML that must
    survive sanitizing, KaTeX fonts and CSP violations.

Every file in `Tests/Page/hosted` returns `JSON.stringify({ results: [{ name, pass, detail, skip }] })`.
Missing bundled KaTeX is a test failure; math checks do not depend on a CDN.

Known defects are listed in `knownFailures` at the top of `HostedRegression.swift`
together with their [BUG_FIXES.md](../BUG_FIXES.md) item. They print `XFAIL` and do not fail the run.
If one passes, the run fails with `XPASS` so the entry is removed after the fix.
No expected failures are currently listed. The two former #20 initial-load failures
now run as ordinary passing checks.

Implementation summaries and feature plans are maintained in
[IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md).
Older raw logs keep their original `CODE_REVIEW #N` labels and former document
name; these refer to the same numbered items in `BUG_FIXES.md`. See
[Result retention](#result-retention) for where they are kept.

```sh
sh Tests/run-relative-images.sh
```

The focused #24 regression loads 54 PNG images across parent paths, Korean/spaced
folders and a read-only document folder, with three fresh views per case. It also
checks JPEG/SVG, encoded filenames, image editing and reopening, document resource
isolation, rejected non-image resources,
and loader invalidation. It uses actual image decoding, with no XFAIL or SKIP.
An optional directory argument retains fixtures for manual GUI checks.

```sh
sh Tests/run-task-lists.sh
```

This command now delegates to the 49-check visual native harness described above.
The retired 17-check legacy task bridge/textarea harness is preserved in Git history
and historical logs. It no longer represents the current click/Esc editing contract.
Hosted task checks exercise read-only and editing permissions in the compatibility path.

### GUI session lifetime

Use [gui-session.mjs](GUI/gui-session.mjs) for CUA app sessions. Paste its factory
without `export` into `cua_repl`, then bind the isolated app by absolute path:

```javascript
var session = await createGUIAppSession(cua, '/private/tmp/example/Bloct Test.app');
var app = session.app;
// Inspect the native Quit menu and its current index before the final action.
await session.finish('click', quitMenuIndex);
```

`finish` retires all references to the wrapped app **before** sending the terminal
action. Later observations and input throw locally, including during a pending
or failed Quit response, so they cannot reactivate a dying process. Confirm actual
PID exit separately before making a new session; app inventory can be stale.
Do not retain or reuse raw CUA handles. Pass the current `app` explicitly into
observation helpers so closures from an earlier run cannot capture retired sessions.

For dirty documents, ordinary Quit can show Save/Don't Save/Cancel without
terminating. Keep using ordinary session actions until the final confirmation
that closes the last document and completes Quit; send that action with `finish`.
If an attempted final action leaves the app alive, inspect its PID before binding
a fresh session instead of reviving the retired handle.

Closing the last document can leave a live macOS app with no windows.
`noWindowsAvailable` alone does not imply termination or a deadlock. Verify the
PID and use a known app action such as New Document or Quit; do not repeatedly
capture nonexistent windows or force-relaunch the process.

Run the session regression with `node --test Tests/GUI/gui-session.test.mjs`.
Its four cases cover concurrent observation during Quit, a lost Quit response,
independent fresh sessions and rejection of ambiguous app names. See
[bug 26](../BUG_FIXES.md#26-gui-테스트-중-finder-bloct-is-not-open-anymore) for
the actual three-process GUI/Finder evidence and historical CUA limitations.

### Result retention

`Tests/results/` keeps only the two most recent date folders. When a new date
folder is added, delete the oldest one and change document links into it to a
GitHub permalink at the last release tag that contains the file, as described in
[AGENTS.md](../AGENTS.md). Folders up to 2026-11-10 are available at tag `v2.0.1`:
`https://github.com/JAEHYEON-BAE/bloct/tree/v2.0.1/Tests/results`.

Result folders hold run output and the one-off probes that produced it. Reusable
tools belong directly under `Tests/`. Raw logs are not rewritten.
