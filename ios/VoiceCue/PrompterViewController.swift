import UIKit
import WebKit

/// Hosts the VoiceCue web app full-screen and wires it to the native speech,
/// wake-lock, and storage bridges.
final class PrompterViewController: UIViewController {
    private var webView: WKWebView!
    private let speech = SpeechBridge()
    private let store = NativeStore()

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "LaunchBackground") ?? .black
        speech.delegate = self
        buildWebView()
        webView.load(URLRequest(url: BundleSchemeHandler.startURL))

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(didEnterBackground),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    private func buildWebView() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: BundleSchemeHandler.scheme)
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        // Seed first: Bootstrap.js reads it if it has to stand in for localStorage.
        controller.addUserScript(WKUserScript(
            source: "window.__nativeSeed = \(store.seedJSON);",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        if let bootstrap = Self.bootstrapSource {
            controller.addUserScript(WKUserScript(
                source: bootstrap, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        for name in ["speech", "wake", "store"] {
            controller.add(self, name: name)
        }
        config.userContentController = controller

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = view.backgroundColor
        webView.scrollView.backgroundColor = view.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false
        webView.uiDelegate = self
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif
        view.addSubview(webView)
    }

    private static var bootstrapSource: String? {
        guard let url = Bundle.main.url(forResource: "Bootstrap", withExtension: "js", subdirectory: "Web") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Wake lock

    /// The page holds at most one lock at a time and re-requests it whenever the app
    /// returns to the foreground, so this tracks a flag rather than a count.
    private func setWakeHeld(_ held: Bool) {
        UIApplication.shared.isIdleTimerDisabled = held
    }

    @objc private func didEnterBackground() {
        // The mic cannot run in the background, and the page will restart it on return.
        speech.stop()
        store.flush()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// The page retries recognition whenever a session ends, which includes the moment the
    /// app is backgrounded. The mic is unavailable there, so answer with a plain `end` — a
    /// failure would surface a "no microphone" warning the user never caused — and let the
    /// page's own retry pick the session back up on return.
    private func startSpeech(languageTag: String) {
        guard UIApplication.shared.applicationState == .active else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.callNativeSpeech("ended", [])
            }
            return
        }
        speech.start(languageTag: languageTag)
    }

    // MARK: - Calling into the page

    private func callNativeSpeech(_ method: String, _ arguments: [Any]) {
        let encoded = arguments.map(Self.jsLiteral).joined(separator: ",")
        let js = "window.__nativeSpeech && window.__nativeSpeech.\(method)(\(encoded));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private static func jsLiteral(_ value: Any) -> String {
        if let flag = value as? Bool { return flag ? "true" : "false" }
        guard let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
              let json = String(data: data, encoding: .utf8) else { return "null" }
        return String(json.dropFirst().dropLast())
    }
}

// MARK: - Messages from the page

extension PrompterViewController: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let cmd = body["cmd"] as? String else { return }
        switch message.name {
        case "speech":
            if cmd == "start" {
                startSpeech(languageTag: body["lang"] as? String ?? "")
            } else if cmd == "stop" {
                speech.stop()
            }
        case "wake":
            setWakeHeld(cmd == "acquire")
        case "store":
            switch cmd {
            case "set":
                if let key = body["key"] as? String, let value = body["value"] as? String {
                    store.set(key, value)
                }
            case "remove":
                if let key = body["key"] as? String { store.remove(key) }
            case "clear":
                store.clear()
            default:
                break
            }
        default:
            break
        }
    }
}

// MARK: - Speech callbacks

extension PrompterViewController: SpeechBridgeDelegate {
    func speechBridge(_ bridge: SpeechBridge, didProduce chunk: String, isFinal: Bool) {
        callNativeSpeech("result", [chunk, isFinal])
    }

    func speechBridge(_ bridge: SpeechBridge, didFailWith code: String) {
        callNativeSpeech("error", [code])
    }

    func speechBridgeDidEnd(_ bridge: SpeechBridge) {
        callNativeSpeech("ended", [])
    }
}

// MARK: - JavaScript dialogs

/// Without this, `confirm()` resolves to false without ever showing anything — the
/// editor's Delete button would quietly do nothing.
extension PrompterViewController: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }
}
