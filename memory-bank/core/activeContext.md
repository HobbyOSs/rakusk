# Active Context

## 現在の焦点
- **Mission: Day 06 Suite (Harib03e) 以降のサポート**
- C言語との連携開始に伴う、アセンブラ機能の拡張（スタック操作、PUSH/POP、CALL/RET等の精度向上）。

## 直近のタスク
- [ ] `make test` を実行し、Day 01〜05 までのテストが全てパスすることを確認する。
- [ ] Day 06 (Harib03e) のテストケースを特定または作成する。
- [ ] Harib03e のアセンブルに必要な不足命令や構文を洗い出す。

## 次のステップ
- テスト結果を確認後、不足している命令の定義を `data/instructions.json` に追加する。
- Pass 1 / Pass 2 での特殊なエンコードが必要な場合は実装を拡張する。