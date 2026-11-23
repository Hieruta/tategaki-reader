import Foundation

/// テキストファイルの読み込みと文字コード判定。
/// UTF-8 を優先し、失敗したら Shift_JIS、それも駄目なら UTF-16 / ロッシー変換の順に試す。
enum TextLoader {
    static func load(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return decode(data)
    }

    static func decode(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) {
            return s
        }
        if let s = String(data: data, encoding: .shiftJIS) {
            return s
        }
        if let s = String(data: data, encoding: .utf16) {
            return s
        }
        // 最終手段：読めないバイトは置換しながらでも表示する
        return String(decoding: data, as: UTF8.self)
    }
}
