import SwiftUI

@main
struct MarkdownViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(document: file.document)
        }
        .defaultSize(width: 900, height: 1600)
    }
}
