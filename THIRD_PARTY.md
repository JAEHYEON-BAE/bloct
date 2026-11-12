# Third-party assets

## Visual editor and block model (Editor/)

Exact dependency versions and npm archive integrity values are recorded in
`Editor/package-lock.json`. The model uses `@tiptap/pm` (ProseMirror, MIT),
`mdast-util-from-markdown`, `mdast-util-to-markdown`, `mdast-util-gfm`,
`mdast-util-math`, and their micromark extensions (MIT). TypeScript (Apache-2.0), esbuild (MIT) and Node type definitions
(MIT) are development tools. Installed dependency packages retain their license
files. `Editor/build-resources.mjs` collects production dependency license texts
into `editor-licenses.txt`, bundled with `blocks.js`, `visual.css`, `math.js` and
`math.css`.

Both the Markdown preview and visual editor use KaTeX 0.18.2 (MIT), including
its WOFF2 fonts embedded in the CSS for offline rendering. Its renderer uses `trust: false`; the tokenizer's
indirect KaTeX is pinned to the same version. The same locked version and options are used across editor switches.

## DOMPurify 3.4.17

- Project: https://github.com/cure53/DOMPurify
- Distribution: https://registry.npmjs.org/dompurify/-/dompurify-3.4.17.tgz
- Vendored file: `Sources/Bloct/Resources/Vendor/purify.min.js` (unmodified distribution file).
- License: Apache-2.0; complete text in `Sources/Bloct/Resources/Vendor/DOMPurify-LICENSE.txt`, bundled with the app.
- npm archive integrity, checked before extraction:
  `sha512-B/pSlYVHQ58kqISD/yDjuJ1yfzI34m1gF4lAod2bwSRhiN4K5Cl3H8Af7hqB2PmTL911tdEudnnXn5FnhRoz0w==`

The sanitizer runs locally and is required before inserting rendered document HTML.
When upgrading it, review upstream security notes and run `sh Tests/run-webkit.sh`.

## Existing renderer assets

`Sources/Bloct/Resources/Vendor/marked.min.js` retains its upstream license header. The former
KaTeX 0.16.11 CDN script/stylesheet are replaced by the shared bundled assets.
