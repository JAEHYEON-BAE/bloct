import Foundation
import UniformTypeIdentifiers
import WebKit

/// Only image responses cross into WebKit; the page never receives broad file access.
@MainActor
final class LocalImageLoader: NSObject, WKURLSchemeHandler {
    static let scheme = "bloct-image"
    private(set) var host = UUID().uuidString.lowercased()
    private var documentURL: URL?
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    func setDocumentURL(_ url: URL?) {
        guard documentURL != url else { return }
        invalidate()
        documentURL = url
        host = UUID().uuidString.lowercased()
    }

    func invalidate() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        documentURL = nil
    }

    func imageURL(for request: URLRequest) -> URL? {
        guard request.httpMethod == "GET", let url = request.url,
              url.scheme == Self.scheme, url.host == host,
              let documentURL, documentURL.isFileURL,
              let source = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "src" })?.value,
              let image = URL(string: source, relativeTo: documentURL.deletingLastPathComponent())?.absoluteURL,
              image.isFileURL, image.host == nil || image.host == "" || image.host == "localhost"
        else { return nil }
        return image.standardizedFileURL.resolvingSymlinksInPath()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let image = imageURL(for: urlSchemeTask.request),
              let type = UTType(filenameExtension: image.pathExtension), type.conforms(to: .image),
              let mime = type.preferredMIMEType, let requestURL = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }
        let key = ObjectIdentifier(urlSchemeTask)
        tasks[key] = Task {
            let result = await Task.detached {
                Result { () throws -> Data in
                    guard try image.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                        throw URLError(.noPermissionsToReadFile)
                    }
                    return try Data(contentsOf: image)
                }
            }.value
            guard !Task.isCancelled else { return }
            tasks[key] = nil
            switch result {
            case .success(let data):
                urlSchemeTask.didReceive(URLResponse(url: requestURL, mimeType: mime,
                                                    expectedContentLength: data.count, textEncodingName: nil))
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            case .failure(let error): urlSchemeTask.didFailWithError(error)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }
}
