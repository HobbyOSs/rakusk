# Active Context

## 現在の焦点
- **Mission: Day 09 Suite (Harib06b/c) 以降のサポート**
- マウス、メモリ管理、割り込み処理に関連する命令セットの拡充。

## 直近のタスク
- [x] Day 06 (Harib03e) をパスさせる。
- [x] COFF 出力の互換性問題を解決する（シンボル順序、リロケーション、文字列テーブル）。
- [x] Day 09 (Harib06c) のバイナリ一致を確認し、パスさせた。

## 最近の変更点
- `lib/Rakusk/AST/Expression.rakumod`: `is-imm8` メソッドを追加し、符号拡張可能な 8 ビット即値（-128〜127、および 0xffffffff 等の 32 ビット表現）の判定を可能にした。
- `lib/Rakusk/Grammar.rakumod`: 算術演算（ADD, SUB, CMP, AND, OR, XOR, ADC, SBB）の `imm8` 最適化（オペコード `83`）を `!try-special-variant` に実装した。nask との互換性のため、`ADD AX, imm16` 等のサイズが変わらないケースでは最適化を抑制するよう調整した。
- `lib/Rakusk/Pass1/Instruction.rakumod`: 32 ビットモードでのジャンプ命令（Jcc, JMP）の推定サイズをデフォルトで 2 バイト（short jump）に変更し、ラベル位置が nask と一致するようにした。
- `lib/Rakusk/FileFmt/COFF.rakumod`: WCOFF オブジェクトファイルのセクション補助レコードの `Number` フィールドを 0 に設定し、nask の出力と一致させた。

## 課題と次のステップ
- [x] `JMP FAR [mem]` および `CALL FAR [mem]`（間接 FAR ジャンプ/コール）のサポートを追加した。
- [x] 条件分岐命令（Jcc）の `near-jump` バリアントをすべて定義し、`EXTERN` シンボルへのジャンプで適切にリロケーションが生成されるようにした。
- `day03_harib00j.t` 等の 32 ビットモードのテストを含め、主要なデグレが解消されたことを確認する。
- 全テストがパスすることを確認し、残りの Day 課題に進む。

## 得られた知識
- **COFF (WCOFF) の詳細挙動**:
    - `nask` 互換のためには、シンボルテーブルで `EXTERN` を `GLOBAL` より先に配置する必要がある。
    - セクションシンボルの補助レコードの `Number` フィールド（セクション番号）は、`nask` では 0 に設定される。
- **命令エンコード**:
    - `imm8` 形式（オペコード `83`）は符号拡張を伴うため、`0xffffffff` 等も 8 ビット（`-1`）として扱える。