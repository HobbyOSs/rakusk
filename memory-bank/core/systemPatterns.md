# System Patterns - rakusk

## アーキテクチャの概要
Rakuの `Grammar` と `Actions` を核とし、`gosk` の設計を参考にした 2 パス構成のデータ駆動型アセンブラ。

## コアコンポーネント (Module Structure)
1. **Frontend (`Rakusk::Grammar`)**:
   - x86アセンブリの構文解析を担当。
   - `data/instructions.json` から動的にトークンを生成する。
2. **Pass 1 (`Rakusk::Pass1`)**:
   - `Pass1` クラスと `AssemblerActions` クラス。
   - `Pass1` クラスがシンボルテーブルと AST リストを管理し、パース結果の評価（ラベル収集や PC 計算）を担当。
3. **AST (`Rakusk::AST`)**:
   - 命令やオペランドを表現するノードクラス群。
   - 各ノードが自己エンコードロジックを持つ。
4. **Pass 2 (`Rakusk::Pass2`)**:
   - `Pass2` クラス。
   - `Pass1` から受け取った AST を走査し、最終的なバイナリ（`Buf`）を生成する。
5. **Main Pipeline (`Rakusk`)**:
   - 各モジュールを統合し、`assemble` 関数を提供するエントリーポイント。

## 設計方針
- **2パス構成**: 将来的なラベル（前方参照）解決のために、パースと生成を分離。
- **データ駆動**: Rakuのコード変更を最小限にし、JSONデータによる機能拡張を優先。
- **自己増殖型（Self-Evolving）**: AI（Cline）が命令定義を更新し、即座にテスト・検証が走るサイクル。