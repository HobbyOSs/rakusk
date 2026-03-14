# Technical Context - rakusk

## プロジェクト構造
```
.
├── main.raku           # CLI エントリーポイント (ファイル・標準入力対応)
├── data/
│   └── instructions.json # 命令定義データ
├── lib/
│   ├── Rakusk.rakumod  # メインモジュール
│   └── Rakusk/         # サブモジュール群
│       ├── AST.rakumod     # 中間表現定義
│       ├── Grammar.rakumod # 構文解析
│       ├── Pass1.rakumod   # AST構築
│       └── Pass2.rakumod   # バイナリ生成
├── t/                  # ユニットテスト
├── examples/           # アセンブリ言語のサンプルコード
├── scripts/            # 開発用補助スクリプト
└── memory-bank/        # プロジェクト知識ベース
```

## 使用技術
- **言語**: Raku (Rakudo v2024.09+)
- **OS**: Linux
- **外部ツール**:
  - `ndisasm`: 生成バイナリの逆アセンブル検証。
  - `git`: バージョン管理。

## 開発環境
- **ランタイム**: MoarVM
- **依存管理**: zef (JSON::Fast 等を使用)

## 技術的制約
- **ターゲット**: x86 (16-bit real mode / 32-bit protected mode)
- **バイナリ形式**: 生バイナリ (Flat binary)
- **出力サイズ**: ブートセクタの場合、厳密に512バイト。