# System Patterns - rakusk

## アーキテクチャの概要
Rakuの `Grammar` と `Actions` を核とした、データ駆動型アセンブラ。

## コアコンポーネント
1. **Parser (Grammar)**:
   - x86アセンブリの構文解析。
   - 動的な命令生成を可能にする。
2. **Generator (Actions)**:
   - パース結果を受け取り、バイト列（`Buf`）に変換。
   - ModR/M バイト生成などの共通ロジックを関数化。
3. **Validator (Pipeline)**:
   - `ndisasm` を呼び出し、出力バイナリの正確性を自動検証。
4. **Data (JSON/YAML)**:
   - 命令セット（Opcode等）の定義。AIが拡張可能な形式。

## 設計方針
- **自己増殖型（Self-Evolving）**: AI（Cline）が命令定義を更新し、即座にテスト・検証が走るサイクル。
- **データ駆動**: Rakuのコード変更を最小限にし、JSONデータによる機能拡張を優先。
- **抽象化**: 複雑なx86のエンコーディング規則（ModR/M）を関数内に隠蔽し、AIのミスを防止。