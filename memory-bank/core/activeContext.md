<!-- activeContext.md -->
# Active Context

## 最近の変更点
- `lib/Rakusk/Pass1.rakumod` を更新し、シンボル解決（EQU, ラベル）、ビットモード保持（BITS）、ORG/RESB/ALIGNB のサイズ計算、命令サイズ計算（size-of-instruction）の実装を強化。
- `t/pass1.t` を作成し、`gosk` の `pass1_test.go` から主要なテストケース（定数定義、ラベル、現在位置 `$` を含むアドレス計算など）を移植。
- `Pass1` において環境変数（`%env`）に `PC` と `symbols` を渡し、式（`Expression`）を動的に評価する仕組みを導入。

## 現在の焦点
- パス1の実装完了と、パス2（バイナリ生成）への統合。

## 次のステップ
- `lib/Rakusk/Pass2.rakumod` の更新：パス1で解決されたシンボルやビットモードを反映したバイナリ生成の精緻化。
- 命令サイズの計算ロジック（ModR/M等）の更なる抽象化と実装。
