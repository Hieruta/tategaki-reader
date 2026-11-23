import Foundation

/// 設定（文字サイズ）としおり（ファイルごとの読書位置＝文字オフセット）を
/// UserDefaults に保存する小さなストア。
final class LibraryStore: ObservableObject {
    private let defaults = UserDefaults.standard
    private let fontSizeKey = "settings.fontSize"
    private let bookmarksKey = "bookmarks.offsets"

    /// 文字サイズ（pt）。未設定時は 20。
    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: fontSizeKey) }
    }

    /// ファイルキー -> 文字オフセット
    private var bookmarks: [String: Int] {
        didSet { defaults.set(bookmarks, forKey: bookmarksKey) }
    }

    init() {
        let savedFont = UserDefaults.standard.double(forKey: "settings.fontSize")
        self.fontSize = savedFont > 0 ? savedFont : 20
        self.bookmarks = UserDefaults.standard.dictionary(forKey: "bookmarks.offsets") as? [String: Int] ?? [:]
    }

    /// ファイルを一意に識別するキー（ファイル名＋バイト数）。
    static func fileKey(name: String, byteCount: Int) -> String {
        "\(name)#\(byteCount)"
    }

    func bookmark(for key: String) -> Int {
        bookmarks[key] ?? 0
    }

    func saveBookmark(offset: Int, for key: String) {
        guard bookmarks[key] != offset else { return }
        bookmarks[key] = offset
    }
}
