# System Patterns - rakusk

## アーキテクチャの概要
Rakuの `Grammar` と `Actions` を核とし、`gosk` の設計を参考にした 2 パス構成のデータ駆動型アセンブラ。

## コアコンポーネント (Module Structure)
1. **Frontend (`Rakusk::Grammar`)**:
   - x86アセンブリの構文解析を担当。
   - `resources/instructions/` 以下のJSONデータから動的にニーモニックトークンを生成。
   - NASM互換のドット `.` 付き識別子をサポートし、予約語（`EQU` 等）やドット開始ラベルとの衝突を避けるための文法制約（`ident_not_reserved`, `mnemonic_ident`）を実装。
   - `statement` ルールは `||` (First Match) を用いて `LabelStmt` を命令より優先的にマッチさせる構造。
2. **Pass 1 (`Rakusk::Pass1`)**:
   - `Pass1` クラスを `Rakusk::Pass1::Core` として実装。
   - 肥大化を防ぐため、以下のサブモジュール（role）に分割されている。
     - `Rakusk::Pass1::Instruction`: 命令のサイズ計算。
     - `Rakusk::Pass1::Pseudo`: 疑似命令のサイズ計算。
     - `Rakusk::Pass1::Statement`: ラベルや設定の処理、評価関数。
   - シンボルテーブルと AST リストを管理し、PC（プログラムカウンタ）の計算を担当。
3. **AST (`Rakusk::AST`)**:
   - 命令やオペランドを表現するノードクラス群。
   - `Rakusk::AST::*` の各モジュールに分割定義されている。
4. **Pass 2 (`Rakusk::Pass2`)**:
   - `Pass2` クラスを `Rakusk::Pass2::Core` として実装。
   - Pass 1 と同様にサブモジュールに分割されている。
     - `Rakusk::Pass2::Instruction`: 命令のバイナリエンコード。
     - `Rakusk::Pass2::Pseudo`: 疑似命令のデータ生成。
     - `Rakusk::Pass2::Statement`: 評価関数。
   - Pass 1 から受け取った AST を走査し、最終的なバイナリ（`Buf`）を生成する。
5. **Main Pipeline (`Rakusk`)**:
   - 各モジュールを統合し、`assemble` 関数を提供するエントリーポイント。

## 設計方針
- **2パス構成**: 将来的なラベル（前方参照）解決のために、パースと生成を分離。
- **データ駆動**: Raku의 コード変更を最小限にし、JSONデータによる機能拡張を優先。
- **モジュール分割**: 各パスを AST の構造に合わせて `Instruction`, `Pseudo`, `Statement` に分割し、再利用性とメンテナンス性を向上。
- **自己増殖型（Self-Evolving）**: AI（Cline）が命令定義を更新し、即座にテスト・検証が走るサイクル。