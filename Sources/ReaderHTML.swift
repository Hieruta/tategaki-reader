import Foundation

/// 縦書き表示用の HTML を生成する。
/// 描画は WKWebView + CSS `writing-mode: vertical-rl` に任せ、
/// ページ分割・文字オフセット⇔ページの相互変換は JavaScript 側で行う。
///
/// ページ送りの仕組み:
/// - 本文コンテナは右端に固定し、縦書きの行が左方向へ伸びていく。
/// - ページ n はコンテナを translateX(n * 画面幅) して表示する（右→左へ読み進む）。
/// - 現在ページ先頭の文字オフセットを Swift 側へ通知し、しおりとして保存する。
enum ReaderHTML {
    static func makeHTML(text: String, fontSize: Double) -> String {
        let escaped = escapeHTML(text)
        let paragraphs = escaped
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "<p class=\"blank\">&nbsp;</p>" : "<p>\($0)</p>" }
            .joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="ja">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
          html, body {
            margin: 0; padding: 0; height: 100%;
            background: #121212; color: #E0E0E0;
            overflow: hidden;
          }
          #content {
            position: absolute; right: 0; top: 0;
            height: 100%;
            writing-mode: vertical-rl;
            -webkit-writing-mode: vertical-rl;
            font-size: \(fontSize)px;
            line-height: 1.9;
            letter-spacing: 0.03em;
            font-family: "Hiragino Mincho ProN", "YuMincho", serif;
            padding: 24px 20px;
            box-sizing: border-box;
            text-align: justify;
            transition: transform 0.18s ease-out;
            will-change: transform;
          }
          #content p { margin: 0 0 0 0.6em; text-indent: 1em; }
          #content p.blank { text-indent: 0; }
        </style>
        </head>
        <body>
        <div id="content">\(paragraphs)</div>
        <script>
          const content = document.getElementById('content');
          let page = 0;
          let pageCount = 1;
          let pageOffsets = [0]; // 各ページ先頭の文字オフセット

          function pageWidth() { return window.innerWidth; }

          // 指定した文字オフセット位置の、本文先頭（右端）からの水平距離を返す
          function distanceOfOffset(offset) {
            const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT);
            let remaining = offset;
            let node = null;
            while (node = walker.nextNode()) {
              if (remaining <= node.data.length) break;
              remaining -= node.data.length;
            }
            if (!node) return content.scrollWidth;
            const range = document.createRange();
            const pos = Math.min(remaining, node.data.length);
            range.setStart(node, pos);
            range.setEnd(node, pos);
            const rect = range.getBoundingClientRect();
            const base = content.getBoundingClientRect();
            // 縦書き（右→左）では、先頭からの距離 = コンテナ右端 - 対象位置の右端
            return base.right - rect.right;
          }

          // ページ境界の文字オフセット表を二分探索で作る
          function computePages() {
            const total = content.scrollWidth;
            const pw = pageWidth();
            pageCount = Math.max(1, Math.ceil(total / pw));
            const totalChars = content.textContent.length;
            pageOffsets = [0];
            for (let p = 1; p < pageCount; p++) {
              let lo = pageOffsets[p - 1], hi = totalChars;
              while (lo < hi) {
                const mid = Math.floor((lo + hi) / 2);
                if (distanceOfOffset(mid) < p * pw) lo = mid + 1; else hi = mid;
              }
              pageOffsets.push(lo);
            }
          }

          function applyPage() {
            content.style.transform = 'translateX(' + (page * pageWidth()) + 'px)';
            if (window.webkit && window.webkit.messageHandlers.pageChanged) {
              window.webkit.messageHandlers.pageChanged.postMessage({
                page: page,
                pageCount: pageCount,
                offset: pageOffsets[page] || 0
              });
            }
          }

          function nextPage() { if (page < pageCount - 1) { page++; applyPage(); } }
          function prevPage() { if (page > 0) { page--; applyPage(); } }

          // Swift から呼ばれる：文字オフセットへジャンプ（しおり復元用）
          function goToOffset(offset) {
            const d = distanceOfOffset(offset);
            page = Math.min(pageCount - 1, Math.max(0, Math.floor(d / pageWidth())));
            applyPage();
          }

          // Swift から呼ばれる：文字サイズ変更後に再計算する
          function relayout() { computePages(); if (page >= pageCount) page = pageCount - 1; applyPage(); }

          // タップ：左端 30% = 次ページ、右端 30% = 前ページ
          document.addEventListener('click', function(e) {
            const x = e.clientX, w = window.innerWidth;
            if (x < w * 0.3) nextPage();
            else if (x > w * 0.7) prevPage();
          });

          // 横スワイプ：右→左へ送ると次ページ、左→右で前ページ
          let touchX = null;
          document.addEventListener('touchstart', function(e) { touchX = e.changedTouches[0].clientX; }, {passive: true});
          document.addEventListener('touchend', function(e) {
            if (touchX === null) return;
            const dx = e.changedTouches[0].clientX - touchX;
            if (dx < -40) nextPage();
            else if (dx > 40) prevPage();
            touchX = null;
          }, {passive: true});

          window.addEventListener('resize', relayout);
          window.addEventListener('load', function() { computePages(); applyPage(); });
        </script>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
