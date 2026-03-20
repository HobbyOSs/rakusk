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

    # 1. 外部ファイルからの読み込み（開発時）を優先
    my $regs-path = "resources/registers.json".IO;
    if $regs-path.f {
        $regs-content = $regs-path.slurp;

        my $inst-dir = "resources/instructions".IO;
        if $inst-dir.d {
            for dir($inst-dir).grep(*.extension eq 'json') -> $file {
                @inst-contents.push($file.slurp);
            }
        }
    }

    # 2. %?RESOURCES からの読み込みを試行（パッケージ化時）
    if !$regs-content.defined {
        my $res = %?RESOURCES<registers.json>;
        if $res.defined {
            # Slip (複数マッチ) の場合は最初のものを取得
            my $target = $res ~~ Slip ?? $res[0] !! $res;
            if $target.defined {
                $regs-content = $target.slurp;
                for <base.json pseudo.json> -> $file {
                    my $i-res = %?RESOURCES{"instructions/$file"};
                    if $i-res.defined {
                        my $i-target = $i-res ~~ Slip ?? $i-res[0] !! $i-res;
                        @inst-contents.push($i-target.slurp) if $i-target.defined;
                    }
                }
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
sub pack-modrm(:$mod, :$reg, :$rm) is export {
    my $m = ($mod // 0);
    $m = ($m ~~ Int) ?? $m !! (($m ~~ Mu) ?? $m.Int !! 0);
    my $r = ($reg // 0);
    $r = ($r ~~ Int) ?? $r !! (($r ~~ Mu) ?? $r.Int !! 0);
    my $i = ($rm // 0);
    $i = ($i ~~ Int) ?? $i !! (($i ~~ Mu) ?? $i.Int !! 0);
    return ($m +< 6) +| ($r +< 3) +| $i;
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
