# Active Context

## 現在の焦点
- **harib17a (asmhead.nas) における命令サイズ計算不一致の修正**

## 直近のタスク
- [x] `t/day20_harib17a_asmhead.t` の失敗原因を特定（`CMP BYTE [ES:DI+0x19], 8` 等のエンコードミス）
- [x] `lib/Rakusk/Pass2/Instruction.rakumod` のエンコードロジック修正（Memory オペランドの適切な ModR/M 生成）
- [ ] Pass 1 と Pass 2 のサイズ計算の乖離を解消（依然として `expected 400, got 384` となる問題の解決）
- [ ] テストの再実行とパスの確認
- [ ] 変更のコミットと Memory Bank の更新

## 最近の変更点
- **Pass 2 エンコードロジックの改善**: 
    - `encode-modrm-sib-disp` において、`reg-imm` 形式の命令でもオペランドが `Memory` オブジェクトである場合に `encode_mem_op` を呼び出すように変更。これにより、セグメントオーバーライド伴うメモリ参照のエンコードが正しく行われるようになった。
    - `get-prefixes` で `$op.^can('seg_override')` を使用して安全にチェックするように修正。

## 課題と次のステップ
- **サイズ不一致の解消**: Pass 1 が `CMP BYTE [ES:DI+d8], imm8` を 2バイト（プレフィックス等を除いた最小サイズ？）と見積もっている可能性が高い。Pass 2 で生成される実際のバイト数（4〜5バイト）と一致させる必要がある。
- **Pass 1 の `size-of-instruction` の検証**: Pass 1 で `encode-instruction` を呼び出した際、環境変数が正しく渡されているか、シンボル解決の有無がサイズにどう影響しているかを確認する。

## 得られた知識
- **命令定義の落とし穴**: `CMP` などの命令で `reg-imm` と定義されていても、構文解析の結果 `Memory` オペランドが渡されるケースがあり、Pass 2 側でそれを考慮した ModR/M 生成が必要になる。
