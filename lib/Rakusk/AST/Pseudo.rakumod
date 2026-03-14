use v6;
use Rakusk::AST::Base;
use Rakusk::AST::Operand;
use Rakusk::AST::Expression;
use Rakusk::AST::Factor;

unit module Rakusk::AST::Pseudo;

class PseudoNode is Statement is export {
    has $.mnemonic;
    has @.operands;

    method encode(%env = {}) {
        my $bin = Buf.new();
        my $current_pc = %env<PC> // 0;

        given $!mnemonic {
            when 'DB' {
                for @!operands -> $op {
                    if $op ~~ Immediate {
                        my $res = $op.expr.eval(%env);
                        if $res ~~ NumberExp {
                            $bin.push($res.value % 256);
                        } else {
                            # 文字列リテラルの場合などの処理
                            my $s = $op.Str;
                            $bin ~= $s.encode('ascii');
                        }
                    } else {
                        # 直接 Expression の場合や、その他の場合
                        my $res = $op ~~ Expression ?? $op.eval(%env) !! $op;
                        if $res ~~ NumberExp {
                            $bin.push($res.value % 256);
                        } elsif $res ~~ Str {
                            $bin ~= $res.encode('ascii');
                        }
                    }
                }
            }
            when 'DW' {
                for @!operands -> $op {
                    my $val = self!eval-to-int($op, %env);
                    $bin.push($val % 256);
                    $bin.push(($val +> 8) % 256);
                }
            }
            when 'DD' {
                for @!operands -> $op {
                    my $val = self!eval-to-int($op, %env);
                    $bin.push($val % 256);
                    $bin.push(($val +> 8) % 256);
                    $bin.push(($val +> 16) % 256);
                    $bin.push(($val +> 24) % 256);
                }
            }
            when 'RESB' {
                my $size = self!eval-to-int(@!operands[0], %env);
                $bin.push(0) for 1..$size;
            }
            when 'ALIGNB' {
                my $boundary = self!eval-to-int(@!operands[0], %env);
                my $padding = ($boundary - ($current_pc % $boundary)) % $boundary;
                $bin.push(0) for 1..$padding;
            }
            when 'ORG' {
                # ORG itself doesn't emit bytes
            }
        }
        return $bin;
    }

    method !eval-to-int($op, %env) {
        if $op ~~ Immediate {
            my $res = $op.expr.eval(%env);
            return $res.value if $res ~~ NumberExp;
        } elsif $op ~~ Expression {
            my $res = $op.eval(%env);
            return $res.value if $res ~~ NumberExp;
        } elsif $op ~~ Int {
            return $op;
        }
        return 0;
    }
}