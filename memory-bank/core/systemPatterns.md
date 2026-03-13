# System Patterns - rakusk

## アーキテクチャの概要
Rakuの `Grammar` と `Actions` を核とし、`gosk` の設計を参考にした 2 パス構成のデータ駆動型アセンブラ。

## コアコンポーネント (Module Structure)
1. **Frontend (`Rakusk::Grammar`)**:
   - x86アセンブリの構文解析を担当。
   - `data/instructions.json` から動的にトークンを生成する。
2. **Pass 1 (`Rakusk::Pass1`)**:
   - `AssemblerActions` クラス。
   - 構文解析結果を受け取り、中間表現（AST）を構築する。
3. **AST (`Rakusk::AST`)**:
   - 命令やオペランドを表現するノードクラス群。
   - 各ノードが自己エンコードロジックを持つ。
4. **Pass 2 (`Rakusk::Pass2`)**:
   - AST を走査し、最終的なバイナリ（`Buf`）を生成する。
   - ラベル解決やセグメント調整などの後処理を行う場所。
5. **Main Pipeline (`Rakusk`)**:
   - 各モジュールを統合し、`assemble` 関数を提供するエントリーポイント。

## 設計方針
- **2パス構成**: 将来的なラベル（前方参照）解決のために、パースと生成を分離。
- **データ駆動**: Rakuのコード変更を最小限にし、JSONデータによる機能拡張を優先。
- **自己増殖型（Self-Evolving）**: AI（Cline）が命令定義を更新し、即座にテスト・検証が走るサイクル。