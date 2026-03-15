# Active Context

## 現在の焦点
- **Mission: Day 09 Suite (Harib06b/c) 以降のサポート**
- マウス、メモリ管理、割り込み処理に関連する命令セットの拡充。

## 直近のタスク
- [x] Day 20 (`harib17b`) の不一致原因調査と主要な修正（PUSH [mem], リロケーションオフセット, 32bitアドレッシング）。
- [x] `base.json` への `PUSH/POP [mem]` バリアント追加。

## 最近の変更点
- `data/instructions/base.json`: `PUSH/POP` のメモリバリアント追加、`PUSHFD/POPFD/IRETD` 等への `width` 指定追加。
- `lib/Rakusk/Grammar.rakumod`: 現在の `bit_mode` に一致する `width` を持つバリアントを優先選択するよう改善。
- `lib/Rakusk/Pass2/Instruction.rakumod`: 
    - 32ビットモードでの `[disp32]`（レジスタなし）アドレッシングをデフォルト化。
    - `needs_67h` の判定ロジック修正（32bitモードでの16bitレジスタ使用時のみ付加）。
    - リロケーションオフセット計算に命令プレフィックス長を加算。
    - `mem-far` 型での `extension` 指定を ModR/M に反映。
- `lib/Rakusk/Pass1/Instruction.rakumod`: `reg/sreg` 型のサイズ推定精度を向上（1バイトとしてカウント）。
- `lib/Rakusk/FileFmt/COFF.rakumod`: リロケーションテーブルポインタを raw data 直後に配置。

## 課題と次のステップ
- `day20_harib17b.t` でのシンボルアドレスの微細なズレ（2バイト）の解消。
- 一部のテストで見られる数バイトのサイズ不一致（ジャンプ命令の最適化の差異など）を精査する。
- `day21` 以降の構文エラー（セグメントプレフィックス等）への対応。

## 得られた知識
- **COFF (WCOFF) の詳細挙動**:
    - `nask` 互換のためには、シンボルテーブルで `EXTERN` を `GLOBAL` より先に配置する必要がある。
    - セクションシンボルの補助レコードの `Number` フィールド（セクション番号）は、`nask` では 0 に設定される。
- **命令エンコード**:
    - `imm8` 形式（オペコード `83`）は符号拡張を伴うため、`0xffffffff` 等も 8 ビット（`-1`）として扱える。