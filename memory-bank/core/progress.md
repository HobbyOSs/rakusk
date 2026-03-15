# Progress - rakusk

## 実装済み機能 (Day 01 - Day 15+)
- [x] 基本命令セット (MOV, ADD, SUB, CMP, JMP, CALL, RET, INT 等)
- [x] 算術演算の `imm8` 最適化 (オペコード `83`)
- [x] 条件分岐 (Jcc) の 8bit/32bit 選択とリロケーション生成
- [x] 間接 FAR ジャンプ/コール (`JMP FAR [mem]`, `CALL FAR [mem]`)
- [x] 16ビット/32ビット ModR/M エンコード
- [x] セグメントレジスタ、コントロールレジスタ対応
- [x] 疑似命令 (ORG, DB, DW, DD, RESB, ALIGNB, EQU, GLOBAL, EXTERN)
- [x] パディング・シグネチャ自動付与 (Day 02/03ブートセクタ対応)
- [x] 2パス構成によるラベル解決
- [x] 自動テストパイプライン (ndisasm 比較)
- [x] **COFF (WCOFF) 出力サポートの改善 (Day 06/09対応)**
    - リロケーションインデックスの正確な計算
    - 文字列テーブルの構築順序（定義順）の維持
    - セクション補助レコード（リロケーション数、Number=0）の付与

## 現在の進捗状況
- **Day 01 〜 Day 06**: 完了（Harib03e までパス）
- **Day 09**: 完了（Harib06c までパス）

## 未実装 / 今後の課題 (Issue #12 より)
- [ ] デグレの修正 (FAR ジャンプ等)
- [ ] Day 12Suite Harib09a
- [ ] Day 15Suite Harib12a/b/c
- [ ] Day 20Suite Harib17b/c/d/e/g/h
- [ ] Day 21Suite Harib18d/e/g
- [ ] Day 22Suite Harib19b/c
- [ ] Day 25Suite Harib22f

## マイルストーン
1. **[DONE] Bootloader Excellence**: Day 01〜05 のブートローダー関連を完全にパス。
2. **[DONE] C-Language Bridge**: Day 06 以降、C言語から呼ばれるアセンブラ関数の完全なアセンブル。
3. **[ACTIVE] Advanced OS Features**: メモリ管理、割り込み処理、マルチタスクに必要な命令セットの網羅。