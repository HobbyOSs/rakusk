# Progress - rakusk

## 実装済み機能
- [x] Pass 1 / Pass 2 のモジュール分割とディレクトリ構造の整理 (`lib/Rakusk/`)
- [x] Pass 1 実装の強化と `gosk` からの命令ハンドラ移植 (`lib/Rakusk/Pass1.rakumod`)
- [x] 各種命令（MOV, RET, JMP, INT, 算術・論理演算等）のサイズ計算
- [x] 疑似命令（ORG, DB, DW, DD, RESB, ALIGNB, GLOBAL, EXTERN）のサポート
- [x] e2eテスト用ヘルパーの移植と修正 (`t/TestHelper.rakumod`)
- [x] AST中間表現の導入と定数畳み込みの強化
- [x] 文法（Grammar）の `spec.md` 準拠とパース精度向上
- [x] 命令定義のデータ駆動化 (JSON)
- [x] `ndisasm` を利用した自動テストパイプライン

## 未実装 / 今後の予定 (goskからの移植課題含む)
- [ ] **ModR/M 計算エンジン**: オペランドの組み合わせに応じた正確なサイズ・バイト列生成
- [ ] **FAR ジャンプ (SegmentedAddress) 対応**: AST定義およびパス1/2での処理
- [ ] **メモリオペランドの間接ジャンプ**: `JMP [EAX]` 等のサイズ推定
- [ ] **Pass 2 の完全実装**: シンボル解決を伴うバイナリ出力
- [ ] **512バイトブートセクタ出力機能**: パディング・シグネチャ自動付与
- [ ] **セクション管理**: `.text`, `.data` 等のセクション切り替え

## 既知の問題
- 特になし。

## マイルストーン
1. **Infrastructure**: Raku + ndisasm による検証パイプラインの完成。 (完了)
2. **Basic ISA**: MOV, JMP, 算術演算などの基本命令の実装。 (Pass1完了、Pass2進行中)
3. **Bootloader**: 実際にQEMU等で起動可能な `boot.bin` の生成。