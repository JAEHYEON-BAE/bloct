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

@main
struct MarkdownViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.document)
        }
        .defaultSize(width: 900, height: 1600)
        .commands { ZoomCommands() }
    }
}
