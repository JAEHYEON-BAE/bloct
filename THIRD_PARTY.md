# Third-party assets

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
