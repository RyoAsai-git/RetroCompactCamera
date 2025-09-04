# Retro Compact Camera

2000年代のコンパクトデジタルカメラを再現したiOSカメラアプリです。

## 概要

このアプリは、2000年代のデジタルカメラの撮影体験を現代のiPhoneで再現することを目的としています。画質特性、UI、操作感を懐かしい形で再現し、現代ユーザーに"デジカメ時代の体験"を提供します。

## 主要機能

### 📸 撮影機能
- リアルタイムプレビュー
- タップフォーカス
- シャッター音（iOS標準音 + 演出音）
- フラッシュエフェクト

### 🎨 年代別モード
1. **Early Digital (2000年代前期)**
   - 低解像度（640×480）
   - 強めのノイズ・青被りホワイトバランス
   - 彩度低め

2. **Compact Digital (2000年代中期)**
   - バランス良い発色（1600×1200）
   - 中程度のシャープネス
   - 擬似フラッシュ演出
   - 顔認識UI（矩形枠表示）

3. **Superzoom Compact (2000年代後期)**
   - 手ブレ風モーションブラー
   - 高感度ノイズ（ISO 800相当）
   - 動画モード風UI（赤RECマーク）

### 🖼️ 画像処理エフェクト
- Core Imageを使用した高品質処理
- 彩度・コントラスト調整
- シャープネス処理
- ノイズ追加
- レンズ歪曲
- 周辺減光（ビネット）
- モーションブラー（Superzoomモード）

### 📊 疑似EXIF情報
- 撮影日時
- カメラメーカー・機種名（年代別）
- ISO感度
- 焦点距離
- 絞り値
- シャッタースピード
- 解像度

### 📱 コンデジ風UI
- **ファインダー画面**
  - バッテリー残量表示
  - 日時表示
  - モード切替
  - 撮影ボタン
  
- **撮影演出**
  - 緑のオートフォーカス枠
  - シャッター音 & フラッシュエフェクト
  
- **ギャラリーモード**
  - サムネイル一覧
  - 詳細表示（EXIF情報付き）

## 技術仕様

### 対応環境
- **OS**: iOS 17以上
- **デバイス**: iPhone 12以降
- **言語**: Swift

### 技術スタック
- **UI**: UIKit + Storyboard
- **撮影**: AVFoundation
- **画像処理**: Core Image + Metal
- **データ保存**: PhotoKit + Core Data
- **サウンド**: AVAudioPlayer

### アーキテクチャ
```
RetroCompactCamera/
├── App/                    # アプリ設定
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Controllers/            # ビューコントローラー
│   ├── CameraViewController.swift
│   ├── GalleryViewController.swift
│   └── PhotoDetailViewController.swift
├── Models/                 # データモデル
│   └── EraMode.swift
├── Managers/              # 機能管理クラス
│   ├── CameraManager.swift
│   ├── ImageProcessor.swift
│   └── ExifManager.swift
└── Resources/             # リソース
    ├── Assets.xcassets
    ├── Main.storyboard
    ├── LaunchScreen.storyboard
    └── Info.plist
```

## セットアップ

1. **Xcodeでプロジェクトを開く**
   ```bash
   open RetroCompactCamera.xcodeproj
   ```

2. **必要な権限を確認**
   - カメラアクセス権限
   - フォトライブラリアクセス権限

3. **実機またはシミュレーターでビルド・実行**

## 使用方法

1. **撮影モードの選択**
   - 画面下部のセグメントコントロールで年代別モードを選択

2. **撮影**
   - 画面をタップしてフォーカス
   - 白いシャッターボタンで撮影

3. **ギャラリー表示**
   - 右下のフォルダーボタンでギャラリーを開く
   - 写真をタップして詳細表示
   - INFOボタンでEXIF情報を表示

## 今後の拡張予定

- 動画撮影対応
- フィルム風エフェクト
- SNS連携機能
- コレクション要素（追加プリセット）

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 開発者

- 開発: Claude (Anthropic)
- 企画・仕様: ryoasai

---

*懐かしいデジカメ体験をお楽しみください！* 📷✨
