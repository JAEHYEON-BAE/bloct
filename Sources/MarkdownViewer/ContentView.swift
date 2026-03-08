import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument

    var body: some View {
        MarkdownWebView(markdown: document.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
