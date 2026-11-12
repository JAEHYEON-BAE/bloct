import SwiftUI

@main
struct BloctApp: App {
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
            QuitCommands()
        }
    }
}
