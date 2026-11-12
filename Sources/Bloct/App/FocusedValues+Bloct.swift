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

struct ExportPDFKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var exportPDF: (() -> Void)? {
        get { self[ExportPDFKey.self] }
        set { self[ExportPDFKey.self] = newValue }
    }
}

struct ShowTOCKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var showTOC: Binding<Bool>? {
        get { self[ShowTOCKey.self] }
        set { self[ShowTOCKey.self] = newValue }
    }
}

struct ShowSearchKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var showSearch: Binding<Bool>? {
        get { self[ShowSearchKey.self] }
        set { self[ShowSearchKey.self] = newValue }
    }
}

struct SaveDocumentKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var saveDocument: (() -> Void)? {
        get { self[SaveDocumentKey.self] }
        set { self[SaveDocumentKey.self] = newValue }
    }
}

struct DocumentUndoKey: FocusedValueKey { typealias Value = () -> Void }
struct DocumentRedoKey: FocusedValueKey { typealias Value = () -> Void }
struct CloseDocumentKey: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
    var documentUndo: (() -> Void)? {
        get { self[DocumentUndoKey.self] }
        set { self[DocumentUndoKey.self] = newValue }
    }
    var documentRedo: (() -> Void)? {
        get { self[DocumentRedoKey.self] }
        set { self[DocumentRedoKey.self] = newValue }
    }
    var closeDocument: (() -> Void)? {
        get { self[CloseDocumentKey.self] }
        set { self[CloseDocumentKey.self] = newValue }
    }
}
