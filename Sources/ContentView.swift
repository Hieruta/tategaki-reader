import SwiftUI
import UniformTypeIdentifiers

/// メイン画面。
/// - 起動直後は同梱サンプルを表示する
/// - ファイルピッカーで .txt を開ける（セキュリティスコープ付き URL に対応）
/// - 読書位置（文字オフセット）をファイルごとに保存・復元する
struct ContentView: View {
    @StateObject private var store = LibraryStore()

    @State private var text: String = SampleText.body
    @State private var title: String = SampleText.title
    @State private var currentKey: String = "sample"
    @State private var restoreOffset: Int = 0

    @State private var isImporterPresented = false
    @State private var isSettingsPresented = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ReaderView(
                text: text,
                fontSize: store.fontSize,
                restoreOffset: restoreOffset,
                onOffsetChanged: { offset in
                    store.saveBookmark(offset: offset, for: currentKey)
                }
            )
            .ignoresSafeArea(edges: .bottom)
            .background(Color(red: 0x12/255, green: 0x12/255, blue: 0x12/255))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Image(systemName: "folder")
                    }
                    .accessibilityLabel("ファイルを開く")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "textformat.size")
                    }
                    .accessibilityLabel("文字サイズ設定")
                }
            }
            .preferredColorScheme(.dark)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [UTType.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                openFile(url)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(fontSize: $store.fontSize)
                .preferredColorScheme(.dark)
        }
        .alert("ファイルを開けませんでした", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func openFile(_ url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let decoded = TextLoader.decode(data)
            let key = LibraryStore.fileKey(name: url.lastPathComponent, byteCount: data.count)
            currentKey = key
            title = url.deletingPathExtension().lastPathComponent
            restoreOffset = store.bookmark(for: key)
            text = decoded
        } catch {
            importError = error.localizedDescription
        }
    }
}

/// 文字サイズ設定シート。
struct SettingsView: View {
    @Binding var fontSize: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("文字サイズ") {
                    Slider(value: $fontSize, in: 14...32, step: 1)
                    Text("\(Int(fontSize)) pt")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Text("あのイーハトーヴォのすきとおった風、夏でも底に冷たさをもつ青いそら。")
                        .font(.system(size: fontSize))
                } header: {
                    Text("プレビュー")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
