use v6;
use JSON::Fast;
use Rakusk::AST;

unit module Rakusk::Util;

our $REGS_PATH = "data/registers.json";
our $INST_DIR  = "data/instructions";

# データ読み込み用のキャッシュ
our %REGS_DATA is export = from-json($REGS_PATH.IO.slurp);
our %INST_DATA is export;

for dir($INST_DIR).grep(*.extension eq 'json') -> $file {
    my %sub-data = from-json($file.IO.slurp);
    for %sub-data.kv -> $key, $val {
        %INST_DATA{$key} = $val;
    }
}

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
