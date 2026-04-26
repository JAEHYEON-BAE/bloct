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
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Close") {
                NSApp.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }
    }
}

struct UndoCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                NSApp.keyWindow?.undoManager?.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            Button("Redo") {
                NSApp.keyWindow?.undoManager?.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
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


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let docWindows = NSApp.windows.filter { $0.delegate is CloseProxy }
        guard !docWindows.isEmpty else { return .terminateNow }

        let anyUnsaved = docWindows.contains {
            ($0.delegate as? CloseProxy)?.hasUnsavedChanges() == true
        }
        guard anyUnsaved else { return .terminateNow }

        docWindows.forEach { $0.performClose(nil) }
        return .terminateCancel
    }
}

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 900, height: 1600)
        .commands {
            CloseDocumentCommands()
            UndoCommands()
            ZoomCommands()
            ExportCommands()
            TOCCommands()
            FindCommands()
            SaveCommands()
        }
    }
}
