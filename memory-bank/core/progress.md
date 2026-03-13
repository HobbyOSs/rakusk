# Progress - rakusk

## 実装済み機能
- [x] プロジェクト初期化
- [x] Raku実行環境の確認 (Rakudo v2024.09)
- [x] Gitリポジトリのセットアップ
- [x] 基本的な `README.md` および `META6.json` の作成
- [x] Memory Bank (core) の整備
- [x] 最小限のパースエンジンの構築 (CLI, HLT命令)
- [x] `ndisasm` を利用した自動テストパイプラインのプロトタイプ
- [x] 命令定義のデータ駆動化 (JSON)
- [x] アセンブラのモジュール化 (`lib/Rakusk.rakumod`)
- [x] Raku標準のユニットテスト導入 (`t/assembler.t`)
- [x] 大量の1バイト命令のサポート (`gosk`参考)
- [x] `MOV reg, imm8` の基本実装
- [x] `gosk` の `spec.md` を取り込み

## 未実装 / 今後の予定
- [ ] ModR/M バイト生成ロジックの抽象化
- [ ] 512バイトブートセクタ出力機能 (パディング・シグネチャ)

## 既知の問題
- 特になし。

## マイルストーン
1. **Infrastructure**: Raku + ndisasm による検証パイプラインの完成。
2. **Basic ISA**: MOV, HLT, CLI などの基本命令の実装。
3. **Bootloader**: 実際にQEMU等で起動可能な `boot.bin` の生成。