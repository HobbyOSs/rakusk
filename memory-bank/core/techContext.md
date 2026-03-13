# Technical Context - rakusk

## 使用技術
- **言語**: Raku (Rakudo v2024.09+)
- **OS**: Linux
- **外部ツール**:
  - `ndisasm`: 生成バイナリの逆アセンブル検証。
  - `git`: バージョン管理。

## 開発環境
- **ランタイム**: MoarVM
- **依存管理**: zef (現在は手動セットアップ中)

## 技術的制約
- **ターゲット**: x86 (16-bit real mode / 32-bit protected mode)
- **バイナリ形式**: 生バイナリ (Flat binary)
- **出力サイズ**: ブートセクタの場合、厳密に512バイト。