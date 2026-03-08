# MarkdownViewer

A native macOS app for viewing Markdown files. Open any `.md` file with a clean, readable render.

## Requirements

- macOS 14.0 or later

## Installation

1. Download `MarkdownViewer.zip` from the latest [Releases](../../releases) page
2. Unzip and drag `MarkdownViewer.app` to `/Applications`
3. **First launch — Gatekeeper bypass (required, one-time):**
   - Right-click `MarkdownViewer.app` → **Open** → click **Open** in the dialog
   - *Alternative:* run `xattr -cr /Applications/MarkdownViewer.app` in Terminal, then open normally

> The app is unsigned (no Apple Developer account), so macOS Gatekeeper will block a normal double-click on the first launch. The steps above bypass this once; subsequent launches work normally.

## Usage

- Double-click any `.md` file to open it in MarkdownViewer
- Drag a `.md` file onto the app icon
- Use **File → Open** from within the app
