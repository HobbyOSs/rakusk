<!-- activeContext.md -->
# Active Context

## 最近の変更点
- `lib/Rakusk/Grammar.rakumod` の文法定義を拡張・修正
    - `TOP` と `line` の空白処理を改善
    - アドレッシングモード (`addressing`) を拡張し、`base + index * scale + offset/symbol` の形式をサポート
    - `.skip` ディレクティブを追加
    - `offset` に負の数を許可するよう `addressing` トークンを調整
- 新しいテストファイル `t/grammar.t` を追加し、`gosk` の `grammar_test.go` を参考にした広範なテストケースを実装

## 現在の焦点
- 文法パースの安定性向上とテスト網羅率の確保

## 次のステップ
- パースされた結果から AST を構築する処理の確認と強化
- Pass1, Pass2 への文法拡張の影響確認