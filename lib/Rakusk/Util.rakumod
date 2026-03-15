use v6;
use JSON::Fast;
use Rakusk::AST;

unit module Rakusk::Util;

# データ読み込み用のキャッシュ
our %REGS_DATA is export;
our %INST_DATA is export;

# 初期化処理：外部ファイルまたはリソースからデータを読み込む
sub init-data() {
    return if %REGS_DATA.elems > 0;

    my $regs-content;
    my @inst-contents;

    # 1. %?RESOURCES からの読み込みを試行（パッケージ化時）
    if %?RESOURCES{"registers.json"}.defined {
        $regs-content = %?RESOURCES{"registers.json"}.slurp;
        # 命令セットディレクトリ内のファイルを列挙
        # Note: %?RESOURCES の列挙は実装に依存するため、既知のファイル名を指定
        for <base.json pseudo.json> -> $file {
            if %?RESOURCES{"instructions/$file"}.defined {
                @inst-contents.push(%?RESOURCES{"instructions/$file"}.slurp);
            }
        }
    }

    # 2. 外部ファイルからの読み込み（開発時）
    if !$regs-content.defined {
        my $regs-path = "data/registers.json".IO;
        $regs-content = $regs-path.slurp if $regs-path.f;

        my $inst-dir = "data/instructions".IO;
        if $inst-dir.d {
            for dir($inst-dir).grep(*.extension eq 'json') -> $file {
                @inst-contents.push($file.slurp);
            }
        }
    }

    # 3. データのパース
    if $regs-content.defined {
        %REGS_DATA = from-json($regs-content);
    } else {
        die "RAKUSK : Failed to load register definitions";
    }

    for @inst-contents -> $content {
        my %sub-data = from-json($content);
        for %sub-data.kv -> $key, $val {
            %INST_DATA{$key} = $val;
        }
    }
}

# 起動時に一度だけ実行
init-data();

# ModR/Mバイトを組み立てる関数
# [ Mod (2bit) | Reg/Opcode (3bit) | R/M (3bit) ]
sub pack-modrm(Int :$mod, Int :$reg, Int :$rm) is export {
    return ($mod +< 6) +| ($reg +< 3) +| $rm;
}

# リトルエンディアンで数値をBufに変換するユーティリティ
sub pack-le(Int $val, Int $width) is export {
    my $bin = Buf.new();
    my $v = $val;
    for 1..($width / 8) {
        $bin.push($v % 256);
        $v = $v +> 8;
    }
    return $bin;
}

# 文字列をバイナリ（ASCII）に変換するユーティリティ
sub pack-str(Str $val) is export {
    return $val.encode('ascii');
}

# 共通の式評価ロジックを提供するRole
role Evaluator is export {
    method eval-to-int($op, %env) {
        my $res = self.eval-to-any($op, %env);
        return $res if $res ~~ Int;
        return 0;
    }

    method eval-to-str($op, %env) {
        my $res = self.eval-to-any($op, %env);
        return $res if $res ~~ Str;
        return $res.Str if $res.defined;
        return "";
    }

    method eval-to-any($op, %env) {
        if $op ~~ Immediate {
            my $res = $op.expr.eval(%env);
            if $res ~~ NumberExp {
                return $res.value;
            } else {
                return $op.expr.factor.eval(%env);
            }
        } elsif $op ~~ Expression {
            my $res = $op.eval(%env);
            if $res ~~ NumberExp {
                return $res.value;
            }
            return $res;
        } elsif $op ~~ Int | Str {
            return $op;
        }
        return 0;
    }
}
