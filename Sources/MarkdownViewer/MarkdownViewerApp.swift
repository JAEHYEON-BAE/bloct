import SwiftUI

struct ZoomCommands: Commands {
    @FocusedValue(\.zoomLevel) var zoomLevel

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Zoom In") {
                zoomLevel?.wrappedValue = min(4.0, (zoomLevel?.wrappedValue ?? 1.0) * 1.25)
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(zoomLevel == nil)

            Button("Zoom Out") {
                zoomLevel?.wrappedValue = max(0.25, (zoomLevel?.wrappedValue ?? 1.0) / 1.25)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(zoomLevel == nil)

            Button("Actual Size") {
                zoomLevel?.wrappedValue = 1.0
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(zoomLevel == nil)
        }
    }
}

struct ExportCommands: Commands {
    @FocusedValue(\.exportPDF) var exportPDF

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Export as PDF…") {
                exportPDF?()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(exportPDF == nil)
        }
    }
}

struct TOCCommands: Commands {
    @FocusedValue(\.showTOC) var showTOC

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button(showTOC?.wrappedValue == true ? "Hide Table of Contents" : "Show Table of Contents") {
                showTOC?.wrappedValue.toggle()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(showTOC == nil)
        }
    }
}

struct FindCommands: Commands {
    @FocusedValue(\.showSearch) var showSearch

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Find…") {
                showSearch?.wrappedValue = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(showSearch == nil)
        }
    }
}

struct RawEditorCommands: Commands {
    @FocusedValue(\.showRawEditor) var showRawEditor

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button(showRawEditor?.wrappedValue == true ? "Hide Raw Markdown" : "Show Raw Markdown") {
                showRawEditor?.wrappedValue.toggle()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(showRawEditor == nil)
        }
    }
}

@main
struct MarkdownViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.document, fileURL: file.fileURL)
        }
        .defaultSize(width: 900, height: 1600)
        .commands {
            ZoomCommands()
            ExportCommands()
            TOCCommands()
            FindCommands()
            RawEditorCommands()
        }
    }
}
