<!-- activeContext.md -->
# Active Context

## 最近の変更点
- `lib/Rakusk/AST/Expression.rakumod` および `Factor.rakumod` を更新し、定数畳み込み（reduce/eval）の実装を強化。数値計算だけでなく、文字列や文字リテラルの評価、未解決シンボルを含む式の部分評価に対応。
- `lib/Rakusk/Grammar.rakumod` を修正し、式内の `$`（現在位置）や引用符付きリテラルのパース精度を向上。
- `t/expression.t` を作成し、`gosk` のテストケースを参考に、四則演算の優先順位、シンボル解決、アドレス計算のテストを実装。

## 現在の焦点
- パス2（バイナリ生成）における、解決済みシンボルを用いたバイナリ出力の精緻化。

## 次のステップ
- ModR/M バイト生成ロジックの抽象化と実装。
- 実際にブートセクタとして動作する `boot.bin` の生成テスト。
