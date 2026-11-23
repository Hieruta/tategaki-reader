# 縦書きリーダー（仮）

iOS 向けの縦書き小説リーダー MVP です。Swift + SwiftUI で作り、縦書き表示は WKWebView + CSS `writing-mode: vertical-rl` で描画します。

- Bundle ID: `ai.eonshore.tategaki-reader`（仮置き）
- 対応: iOS 17 以上

## 機能（MVP）

1. **ファイルを開く**: ファイルピッカーで `.txt` を開けます。UTF-8 前提ですが、Shift_JIS も可能な範囲で自動判定して変換します。
2. **ダークテーマ既定**: 背景 `#121212` / 文字 `#E0E0E0`。
3. **文字サイズ変更**: 右上のボタンから設定を開き、スライダーで変更。設定は保存されます。
4. **しおり**: ファイルごとに読書位置（文字オフセット）を自動保存し、再オープン時に続きから開きます。
5. **サンプル同梱**: ファイルなしでも同梱サンプルテキストで表示確認ができます。

### 操作

- ページ送りは横方向（右→左へ読み進む）
- 画面左端タップ = 次ページ / 右端タップ = 前ページ
- 横スワイプでもページ移動できます

## 構成

```
novel-reader/
├── project.yml                  # XcodeGen のプロジェクト定義
├── .github/workflows/build.yml  # 署名なし IPA を作る GitHub Actions
└── Sources/
    ├── TategakiReaderApp.swift  # エントリポイント
    ├── ContentView.swift        # メイン画面・ファイルピッカー・設定シート
    ├── ReaderView.swift         # WKWebView の SwiftUI ラッパー
    ├── ReaderHTML.swift         # 縦書き HTML/CSS/JS の生成（ページ分割・オフセット変換）
    ├── TextLoader.swift         # 文字コード判定（UTF-8 → Shift_JIS → …）
    ├── LibraryStore.swift       # 文字サイズとしおり（文字オフセット）の保存
    └── SampleText.swift         # 同梱サンプルテキスト
```

Xcode プロジェクト（`.xcodeproj`）はリポジトリに含めず、XcodeGen（`project.yml`）から生成します。

## GitHub Actions でビルドする

1. このフォルダを GitHub リポジトリに push します（`main` ブランチ）。
2. push すると Actions の `Build unsigned IPA` ワークフローが自動で走ります。手動実行も可能です（Actions タブ → ワークフローを選択 → "Run workflow"）。
3. ワークフロー内では macOS ランナーで次を実行します。
   - `brew install xcodegen` → `xcodegen generate` でプロジェクト生成
   - `xcodebuild`（`CODE_SIGNING_ALLOWED=NO`）で署名なしビルド
   - `.app` を `Payload/` 構成に固めて `TategakiReader.ipa` を作成
4. 完了後、実行ページの **Artifacts** から `TategakiReader-ipa` をダウンロードすると IPA が手に入ります。

> 注意: この IPA は署名されていないため、そのままでは実機にインストールできません。LiveContainer 経由で利用します（下記）。

## LiveContainer へのインストール

1. GitHub Actions の Artifacts から `TategakiReader-ipa`（zip）をダウンロードし、解凍して `TategakiReader.ipa` を取り出します。
2. iPhone の「ファイル」アプリに IPA を保存します。
3. LiveContainer を開き、アプリ追加（＋）から `TategakiReader.ipa` を選択します。
4. 一覧に追加された「縦書きリーダー」をタップして起動します。

LiveContainer 上では署名なしアプリを再署名して実行するため、通常のサイドロードのような 7 日制限や 3 アプリ制限を気にせず、何度でも入れ直して試せます。

## ローカルでビルドする場合（Mac があるとき）

```sh
brew install xcodegen
xcodegen generate
open TategakiReader.xcodeproj
```

## 補足

- 読書位置はページ番号ではなく **文字オフセット** で保存します。文字サイズを変えても、ほぼ同じ位置から読み直せます。
- MVP のため、EPUB 対応・オンライン文庫連携・クラウド同期などは含みません。
