import SwiftUI
import WebKit

/// WKWebView の SwiftUI ラッパー。
/// 縦書き HTML を表示し、ページ変化（＝現在位置の文字オフセット）を
/// コールバックで Swift 側へ返す。しおり復元は restoreOffset で行う。
struct ReaderView: UIViewRepresentable {
    let text: String
    let fontSize: Double
    /// 再オープン時に復元する文字オフセット
    let restoreOffset: Int
    /// ページが変わるたびに現在位置の文字オフセットを通知する
    var onOffsetChanged: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOffsetChanged: onOffsetChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "pageChanged")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor(red: 0x12/255, green: 0x12/255, blue: 0x12/255, alpha: 1)
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        context.coordinator.webView = webView
        context.coordinator.load(text: text, fontSize: fontSize, restoreOffset: restoreOffset)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOffsetChanged = onOffsetChanged
        // テキストが差し替わった場合だけ読み直す（フォント変更は再生成）
        if context.coordinator.loadedText != text || context.coordinator.loadedFontSize != fontSize {
            context.coordinator.load(text: text, fontSize: fontSize, restoreOffset: restoreOffset)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onOffsetChanged: (Int) -> Void
        weak var webView: WKWebView?
        var loadedText: String?
        var loadedFontSize: Double?

        init(onOffsetChanged: @escaping (Int) -> Void) {
            self.onOffsetChanged = onOffsetChanged
        }

        func load(text: String, fontSize: Double, restoreOffset: Int) {
            loadedText = text
            loadedFontSize = fontSize
            let html = ReaderHTML.makeHTML(text: text, fontSize: fontSize)
            webView?.loadHTMLString(html, baseURL: nil)
            // HTML 側のレイアウト完了後にしおり位置へジャンプする
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard restoreOffset > 0 else { return }
                self?.webView?.evaluateJavaScript("goToOffset(\(restoreOffset))")
            }
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "pageChanged",
                  let body = message.body as? [String: Any],
                  let offset = body["offset"] as? Int else { return }
            onOffsetChanged(offset)
        }
    }
}
