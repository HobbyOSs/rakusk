# Progress - rakusk

## 実装済み機能
- [x] プロジェクト初期化
- [x] Raku実行環境の確認 (Rakudo v2024.09)
- [x] Gitリポジトリのセットアップ
- [x] 基本的な `README.md` および `META6.json` の作成
- [x] Memory Bank (core) の整備

## 未実装 / 今後の予定
- [ ] 最小限のパースエンジンの構築 (CLI命令等)
- [ ] `ndisasm` を利用した自動テストパイプライン
- [ ] 命令定義のデータ駆動化 (JSON)
- [ ] ModR/M バイト生成ロジックの抽象化
- [ ] 512バイトブートセクタ出力機能

## 既知の問題
- 特になし。

## マイルストーン
1. **Infrastructure**: Raku + ndisasm による検証パイプラインの完成。
2. **Basic ISA**: MOV, HLT, CLI などの基本命令の実装。
3. **Bootloader**: 実際にQEMU等で起動可能な `boot.bin` の生成。