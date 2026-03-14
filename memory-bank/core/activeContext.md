<!-- activeContext.md -->
# Active Context

## 最近の変更点
- `gosk` の `pass1` 機能を `lib/Rakusk/Pass1.rakumod` に移植。
    - 各種命令のサイズ計算ハンドラ（`MOV`, `RET`, `INT`, `IN/OUT`, `JMP/CALL`, 算術・論理演算, `PUSH/POP`）を実装。
    - パラメータなし命令のサイズ推定例外に対応。
    - `GLOBAL`, `EXTERN` 疑似命令のサポートを追加。
- `memory-bank` の更新と未実装課題の整理。

## 現在の焦点
- パス1におけるアドレッシングモード（ModR/M）を考慮した正確なサイズ計算への移行。
- `Rakusk::AST` における FAR ジャンプ（セグメント付きアドレス）のサポート。

## 次のステップ
- **ModR/M 計算エンジンの実装**: オペランドの組み合わせに基づいた正確なバイトサイズ算出。
- **FAR ジャンプの AST 対応**: `SegmentedAddress` ノードの定義とパース、パス1でのサイズ計算。
- **Pass 2 の精緻化**: 解決済みシンボルを用いた最終的なバイナリ生成。