# Bloct

A native macOS app for viewing and editing Markdown files with a clean, live preview.

## Requirements

- macOS 14.0 or later

## Installation

### Homebrew (recommended)

```sh
brew tap JAEHYEON-BAE/tap
brew install --cask bloct
```

### Manual

1. Download `Bloct.zip` from the latest [Releases](../../releases) page
2. Unzip and drag `Bloct.app` to `/Applications`
3. Run the following in Terminal to bypass Gatekeeper (required once, as the app is unsigned):
   ```sh
   xattr -cr /Applications/Bloct.app
   ```
4. Open Bloct normally from `/Applications`

## Features

### WYSIWYG Inline Editing
Click any block in the preview to edit it directly — no separate editor pane needed. The clicked block is replaced by a textarea pre-filled with the raw Markdown for that block. Press **Escape** or click elsewhere to commit the change and re-render.

### Markdown Rendering
- Full [GitHub Flavored Markdown](https://github.github.com/gfm/) via [marked.js](https://marked.js.org/)
- Fenced code blocks with language labels
- Tables, blockquotes, and horizontal rules
- Math expressions via [KaTeX](https://katex.org/) — inline `$...$` and display `$$...$$`
- Local images resolved relative to the opened file

### Table of Contents
Toggle the TOC panel with the **⇧⌘T** shortcut or the toolbar button. The panel slides in from the left and updates live as you edit headings.

### Find in Document
Press **⌘F** to open the search bar. Matches are highlighted in the preview; navigate between them with **↑ / ↓** or **Return / Shift-Return**.

### Export to PDF
Use **File → Export as PDF** (or the toolbar button) to save the rendered document as a PDF with standard page margins.

### Zoom
Pinch-to-zoom or use **⌘+** / **⌘−** to scale the preview.

### Save
**⌘S** saves changes back to the original `.md` file. A warning is shown if you try to close a window with unsaved changes.

### Scroll Position Memory
The scroll position for each file is restored automatically when you reopen it.

### Dark Mode
Fully adapts to macOS Light and Dark appearance.

## Usage

- Double-click any `.md` file to open it in Bloct
- Drag a `.md` file onto the app icon
- Use **File → Open** from within the app
