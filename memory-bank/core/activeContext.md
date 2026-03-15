# Active Context

## 現在の焦点
- **Mission: Day 09 Suite (Harib06b/c) 以降のサポート**
- マウス、メモリ管理、割り込み処理に関連する命令セットの拡充。

## 直近のタスク
- [x] Day 09 (Harib06c) のバイナリ一致を確認し、パスさせた。
- [x] Day 15 (Harib12c) までのテストがパスすることを確認した。
- [x] デグレ修正：間接 FAR ジャンプの追加、Jcc near バリアントによるリロケーション修正、COFF セクションヘッダの調整。

## 最近の変更点
- `lib/Rakusk/AST/Expression.rakumod`: `is-imm8` メソッドを追加。
- `lib/Rakusk/Grammar.rakumod`: 算術演算の `imm8` 最適化の実装。`EXTERN` シンボルへの short jump 抑制。
- `lib/Rakusk/Pass1/Instruction.rakumod`: 32 ビットモードでのジャンプ命令推定サイズの調整。
- `lib/Rakusk/FileFmt/COFF.rakumod`: セクション補助レコードの `Number` フィールド修正、およびリロケーションテーブルポインタの常時出力（nask互換）。
- `data/instructions/base.json`: 間接 FAR ジャンプ/コール、および Jcc near バリアントの追加。

## 課題と次のステップ
- `day20_harib17b.t` 以降で発生している `PUSH [mem]` 等のバリアント不足を解消する。
- 一部のテストで見られる数バイトのサイズ不一致（ジャンプ命令の最適化の差異など）を精査する。
- `day21` 以降の構文エラー（セグメントプレフィックス等）への対応。

## 得られた知識
- **COFF (WCOFF) の詳細挙動**:
    - `nask` 互換のためには、シンボルテーブルで `EXTERN` を `GLOBAL` より先に配置する必要がある。
    - セクションシンボルの補助レコードの `Number` フィールド（セクション番号）は、`nask` では 0 に設定される。
- **命令エンコード**:
    - `imm8` 形式（オペコード `83`）は符号拡張を伴うため、`0xffffffff` 等も 8 ビット（`-1`）として扱える。