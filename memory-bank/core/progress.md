# Progress - rakusk

## 実装済み機能 (Day 01 - Day 15)
- [x] NASM互換のドット `.` 付き識別子、およびアンダースコア `_` 付きシンボル対応
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
- [x] **COFF (WCOFF) 出力サポートの改善 (Day 06/09/15対応)**
    - リロケーションインデックスの正確な計算
    - 文字列テーブルの構築順序（定義順）の維持
    - セクション補助レコード（リロケーション数、Number=0）の付与
    - リロケーションがない場合でもセクションヘッダにポインタを保持 (nask互換)

## 現在の進捗状況
- **Day 01 〜 Day 15**: 完了（Harib12c までの全テストパスを達成）
- **Day 20 〜**: デグレおよび命令追加が必要

## 未実装 / 今後の課題 (Issue #12 より)
- [x] 32ビットモードにおける `PUSH [mem]` 等のバリアント追加 (Day 20以降で発生)
- [ ] 命令サイズの微細な不一致の修正 (Day 20 harib17b で残り2バイトのズレ)
- [ ] Day 20Suite Harib17b/c/d/e/g/h
- [ ] Day 21Suite Harib18d/e/g
- [ ] Day 22Suite Harib19b/c
- [ ] Day 25Suite Harib22f

## マイルストーン
1. **[DONE] Bootloader Excellence**: Day 01〜05 のブートローダー関連を完全にパス。
2. **[DONE] C-Language Bridge**: Day 06 以降、C言語から呼ばれるアセンブラ関数の完全なアセンブル。
3. **[DONE] Advanced OS Features (Part 1)**: Day 15 (Harib12c) までのメモリ管理・ウィンドウ表示関連の命令・出力をサポート。
4. **[ACTIVE] Advanced OS Features (Part 2)**: マルチタスク、例外処理、高度なアプリ実行に必要な機能の完成。