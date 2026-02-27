# UPM4M (Unity Package Manager for Mac)

Unityのアセット（.unitypackageファイル）を整理・管理するためのネイティブ macOS アプリです。

![macOS](https://img.shields.io/badge/macOS-15.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## バージョン情報
 - Ver1.0 (beta 1)
 
 超ベータ版です。問題が発生した場合はissuesで報告お願いします。

 エクスポート・インポート機能は今後実装予定になります。

## スクリーンショット

 - 準備中

## 機能

- 📦 **パッケージ管理** — 追加・編集・削除・検索・フォルダ別フィルタリング
- 📂 **自動整理** — 追加時にファイルを指定フォルダへ自動コピー
  - 構成: `整理先フォルダ / カテゴリ / パッケージ名 / ファイル`
- 🗂️ **追加ファイル対応** — unitypackage 以外のフォルダ・ファイルも一緒にコピー可能（アバターデータなど）
- 🔗 **販売ページ連携** — URLを登録してページタイトルを取得・保存、ブラウザで直接開く
- 📊 **CSV入出力(今後実装予定)** — Excel対応のUTF-8 BOM付きCSVでエクスポート／インポート
- ⚙️ **設定管理** — 整理先フォルダの変更、カテゴリフォルダの追加・削除、データリセット

## 動作環境

- macOS 15 以降

## インストール

### Xcodeでビルドする

```bash
git clone https://github.com/NobleSys-tk/UnityPackageManager4Mac.git
cd UnityPackageManager4Mac
open UnityPackageManager4Mac.xcodeproj
```

Xcode で `⌘R` を押してビルド・起動します。

### 初回起動時

起動すると整理先フォルダの選択ダイアログが表示されます。  
unitypackageファイルを整理・保存したいフォルダを指定してください。

## 使い方

### パッケージを追加する

1. ツールバーの **「＋ 追加」** ボタンをクリック（または `⌘N`）
2. パッケージ名・ファイル・カテゴリフォルダ・URLなどを入力
3. **「追加」** をクリック → ファイルが整理先フォルダへ自動コピーされます

### アバターデータなど複数ファイルを一緒に管理する

追加フォームの **「追加ファイル・フォルダも一緒にコピー」** トグルをオンにすると、unitypackage以外のフォルダやファイルも一緒にコピーできます。

### CSVでバックアップ・移行する(現在仕様検討中のためオミットしてあります)

- **エクスポート**: ツールバーの `📤 エクスポート`（`⇧⌘E`）
- **インポート**: ツールバーの `📥 インポート`（`⇧⌘I`）

## データの保存場所

```
~/Library/Application Support/UnityPackageManager/
  packages.json   # パッケージ一覧
  settings.json   # 設定（フォルダ・整理先など）
```

設定 (`⌘,`) の **「データ管理」** タブからFinderで開いたりリセットができます。

## ライセンス

[MIT License](LICENSE)
