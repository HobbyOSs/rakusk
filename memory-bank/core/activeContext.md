# Active Context

## 現在の焦点
- **harib17a (asmhead.nas) におけるバイナリ不一致およびサイズ計算乖離の完全解消**

## 直近のタスク
- [x] `t/day20_harib17a_asmhead.t` のバイナリ不一致原因の特定と修正
- [x] Pass 1 と Pass 2 のサイズ計算の乖離（`expected 400, got 384`）の解消
- [x] 負数を含む `pack-le` の挙動修正（ビットマスクの適用）
- [x] 命令選択ロジック（`Actions.rakumod`）の厳密化
- [x] Memory Bank の更新
- [ ] 変更のコミット

## 最近の変更点
- **命令選択とエンコードの修正**:
    - `Actions.rakumod`: `reg-imm` 形式の命令マッチングにおいて、`extension`（グループオペコード）がない場合にメモリオペランドを誤ってマッチさせないようガードを追加。
    - `Pass2/Instruction.rakumod`: プレフィックスの順序を `0x67` (Address Size) -> `0x66` (Operand Size) の順に修正（nask互換）。
    - `Pass2/Instruction.rakumod`: `IMUL r16/r32, imm` 等の `extension` を持たない `reg-imm` 形式で、ModR/M の `reg` フィールドにデスティネーションレジスタを正しく設定するように修正。
- **ユーティリティの改善**:
    - `Util.rakumod`: `pack-le` において、負数が渡された場合に指定ビット幅で正しくマスク（例: 8bit なら `& 0xff`）するように修正。これにより、負のディスプレースメントやイミディエイトのエンコードが安定。
- **Pass 1 サイズ計算の同期**:
    - `Actions.rakumod` での命令選択が Pass 2 と一致したことにより、Pass 1 での見積もりサイズと Pass 2 の実生成サイズが一致。`harib17a` の `expected 400, got 384` 問題が解決。

## 課題と次のステップ
- **全体テストの最終確認**: 大幅な修正（特に命令選択と `pack-le`）を行ったため、他の `harib` テストに副作用がないか確認する。
- **Git コミット**: 修正内容をコミットする。

## 得られた知識
- **nask のプリフィックス順序**: Address Size プレフィックス (`0x67`) は Operand Size プレフィックス (`0x66`) よりも前に配置される必要がある。
- **符号付き整数のバイナリ表現**: Raku の `pack` 挙動に依存せず、明示的にビットマスクをかけることで、16/32bit 環境での負数エンコードの互換性を確保できる。
