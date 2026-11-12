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

struct CloseDocumentCommands: Commands {
    @FocusedValue(\.closeDocument) var closeDocument
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Close") {
                closeDocument?()
            }
            .keyboardShortcut("w", modifiers: .command)
        }
    }
}

struct UndoCommands: Commands {
    @FocusedValue(\.documentUndo) var documentUndo
    @FocusedValue(\.documentRedo) var documentRedo
    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                documentUndo?()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(documentUndo == nil)
            Button("Redo") {
                documentRedo?()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(documentRedo == nil)
        }
    }
}

struct SaveCommands: Commands {
    @FocusedValue(\.saveDocument) var saveDocument

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                saveDocument?()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(saveDocument == nil)
        }
    }
}

struct QuitCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appTermination) {
            Button("Quit Bloct") {
                handleQuit()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
