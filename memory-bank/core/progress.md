# Progress - rakusk

## 実装済み機能
- [x] e2eテスト用ヘルパーの移植 (`t/TestHelper.rakumod`)
- [x] Pass 1 / Pass 2 のモジュール分割とディレクトリ構造の整理 (`lib/Rakusk/`)
- [x] Pass 1 / Pass 2 の基本クラス構造の定義（ラベル解決の準備）
- [x] Pass 2 アセンブラ基盤（AST中間表現）の導入
- [x] ファイルおよび標準入力からの解析サポート（CLIツール化）
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
- [x] キャッシュ機能付き GitHub Actions CI の導入 (JSON::Fastの依存関係追加含む)
- [x] `lib/Rakusk/AST.rakumod` における型付きASTノードの導入
- [x] `lib/Rakusk/Grammar.rakumod` の `spec.md` 準拠修正
- [x] 文法およびASTの単体テストの拡充 (`t/grammar.t`, `t/ast.t`)

## 未実装 / 今後の予定
- [ ] ModR/M バイト生成ロジックの抽象化
- [ ] 512バイトブートセクタ出力機能 (パディング・シグネチャ)

## 既知の問題
- 特になし。

## マイルストーン
1. **Infrastructure**: Raku + ndisasm による検証パイプラインの完成。
2. **Basic ISA**: MOV, HLT, CLI などの基本命令の実装。
3. **Bootloader**: 実際にQEMU等で起動可能な `boot.bin` の生成。