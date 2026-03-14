<!-- activeContext.md -->
# Active Context

## 最近の変更点
- `gosk` からテスト用ヘルパーを Raku に移植 (`t/TestHelper.rakumod`)。16進数DSL (`define-hex`)、hexdump、バイナリ差分表示などの機能を実装。
- `lib/Rakusk/AST.rakumod` において、`Register`, `Immediate` クラスおよび `Operand` ロールを導入し、ASTノード（`LabelStmt`, `DeclareStmt`, `ConfigStmt`, `InstructionNode`, `PseudoNode`）を構造化。
- `lib/Rakusk/Grammar.rakumod` を `memory-bank/docs/spec.md` の仕様に厳密に準拠するよう修正。当初実装していた仕様外の構文（アドレッシングモードやドット開始のディレクティブ）を削除。
- `t/grammar.t` と `t/ast.t` を作成・更新し、仕様に基づいたパースとAST構築が正しく行われることを確認。

## 現在の焦点
- ASTをベースにしたPass1（シンボル解決・ラベル収集）の再構築。

## 次のステップ
- `lib/Rakusk/Pass1.rakumod` の更新：新しいAST構造に対応したパス1の実装。
- シンボルテーブルの管理ロジックの改善。
