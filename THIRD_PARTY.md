# Third-party assets

## Experimental block model (Editor/)

Exact dependency versions and npm archive integrity values are recorded in
`Editor/package-lock.json`. The model uses `@tiptap/pm` (ProseMirror, MIT),
`mdast-util-from-markdown`, `mdast-util-gfm`, `mdast-util-math`, and their micromark
extensions (MIT). TypeScript (Apache-2.0), esbuild (MIT) and Node type definitions
(MIT) are development tools. Installed dependency packages retain their license
files. The generated bundle is currently a test artifact, not an app resource;
app integration must also include the bundled dependency license notices.

The math tokenizer's indirect KaTeX dependency is pinned by an override to 0.18.2.
This model imports the tokenizer, not its KaTeX HTML renderer. The existing app's
CDN KaTeX version below is unchanged.

## DOMPurify 3.4.17

- Project: https://github.com/cure53/DOMPurify
- Distribution: https://registry.npmjs.org/dompurify/-/dompurify-3.4.17.tgz
- Vendored file: `Sources/Bloct/purify.min.js` (unmodified distribution file).
- License: Apache-2.0; complete text in `Sources/Bloct/DOMPurify-LICENSE.txt`, bundled with the app.
- npm archive integrity, checked before extraction:
  `sha512-B/pSlYVHQ58kqISD/yDjuJ1yfzI34m1gF4lAod2bwSRhiN4K5Cl3H8Af7hqB2PmTL911tdEudnnXn5FnhRoz0w==`

The sanitizer runs locally and is required before inserting rendered document HTML.
When upgrading it, review upstream security notes and run `sh Tests/run-webkit.sh`.

## Existing renderer assets

`Sources/Bloct/marked.min.js` retains its upstream license header. KaTeX 0.16.11
continues to load from jsDelivr at runtime; this change does not bundle KaTeX.
