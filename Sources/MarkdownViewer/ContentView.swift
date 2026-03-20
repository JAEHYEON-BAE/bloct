import SwiftUI

struct ZoomLevelKey: FocusedValueKey {
    typealias Value = Binding<Double>
}

extension FocusedValues {
    var zoomLevel: Binding<Double>? {
        get { self[ZoomLevelKey.self] }
        set { self[ZoomLevelKey.self] = newValue }
    }
}

struct ContentView: View {
    let document: MarkdownDocument
    @State private var zoomLevel: Double = 1.0

    var body: some View {
        MarkdownWebView(markdown: document.text, zoomLevel: zoomLevel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusedValue(\.zoomLevel, $zoomLevel)
    }
}
