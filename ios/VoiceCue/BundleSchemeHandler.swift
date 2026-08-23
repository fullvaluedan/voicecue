import Foundation
import WebKit

/// Serves the bundled web app from `voicecue://app/…`.
///
/// A custom scheme (rather than `file://`) gives the page a real, stable origin,
/// which is what lets `localStorage` persist the user's scripts across launches.
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "voicecue"
    static let host = "app"
    static let startURL = URL(string: "\(scheme)://\(host)/index.html")!

    private static let mimeTypes: [String: String] = [
        "html": "text/html", "css": "text/css", "js": "text/javascript",
        "json": "application/json", "woff2": "font/woff2", "woff": "font/woff",
        "ttf": "font/ttf", "png": "image/png", "jpg": "image/jpeg",
        "svg": "image/svg+xml", "ico": "image/x-icon"
    ]

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let fileURL = Self.resolve(url) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        do {
            var data = try Data(contentsOf: fileURL)
            if fileURL.lastPathComponent == "index.html" {
                data = Self.localizingFonts(data)
            }
            let mime = Self.mimeTypes[fileURL.pathExtension.lowercased()] ?? "application/octet-stream"
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
                "Content-Type": mime,
                "Content-Length": String(data.count),
                "Cache-Control": "no-cache",
                "Access-Control-Allow-Origin": "*"
            ])!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    /// Points the page's webfont stylesheet at the bundled copy, so the app renders in its
    /// real typefaces instantly and offline instead of waiting on Google Fonts.
    private static func localizingFonts(_ data: Data) -> Data {
        guard var html = String(data: data, encoding: .utf8) else { return data }
        let pattern = "https://fonts\\.googleapis\\.com/css2\\?[^\"']*"
        html = html.replacingOccurrences(of: pattern, with: "fonts.css",
                                         options: .regularExpression)
        return html.data(using: .utf8) ?? data
    }

    /// Maps a request path onto a bundled file.
    ///
    /// `/` and `/index.html` resolve to the shared `index.html` at the repo root (copied to the
    /// bundle root); everything else resolves inside the bundle's `Web/` folder.
    private static func resolve(_ url: URL) -> URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }

        // Reject traversal before touching the file system.
        let components = path.split(separator: "/").map(String.init)
        guard !components.contains(".."), !components.isEmpty else { return nil }

        let candidate: URL
        if components == ["index.html"] {
            candidate = resources.appendingPathComponent("index.html")
        } else {
            candidate = components.reduce(resources.appendingPathComponent("Web")) {
                $0.appendingPathComponent($1)
            }
        }
        let resolved = candidate.standardizedFileURL
        guard resolved.path.hasPrefix(resources.standardizedFileURL.path),
              FileManager.default.fileExists(atPath: resolved.path) else { return nil }
        return resolved
    }
}
