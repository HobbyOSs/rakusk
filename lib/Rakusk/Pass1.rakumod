use v6;
unit module Rakusk::Pass1;
use Rakusk::AST;

class Pass1 is export {
    has %.symbols;
    has @.ast;
    has Int $.pc = 0;

    method evaluate(@ast, %regs) {
        @!ast = @ast;
        
        # パス1: ラベル・定数の収集とPCの計算
        $!pc = 0;
        for @!ast -> $node {
            if $node ~~ LabelStmt {
                %!symbols{$node.label} = $!pc;
                next;
            }
            if $node ~~ DeclareStmt {
                %!symbols{$node.name} = $node.value; # TODO: 式の評価
                next;
            }

            # ORG 命令の特別な処理
            if $node ~~ PseudoNode && $node.mnemonic eq 'ORG' {
                my $val = $node.operands[0];
                $!pc = $val ~~ Immediate ?? $val.Int !! $val.Int;
                next;
            }

            # 環境の構築
            my %env = symbols => %!symbols, PC => $!pc;

            if $node ~~ InstructionNode {
                $!pc += self!size-of-instruction($node, %regs, %env);
            }
            elsif $node ~~ PseudoNode {
                my $size = self!size-of-pseudo($node, %env);
                $!pc += $size;
            }
        }
        return self;
    }

    method !size-of-instruction($node, %regs, %env) {
        my %info = $node.info;
        if %info<type> eq 'no-op' {
            return 1;
        }
        elsif %info<type> eq 'reg-imm8' {
            return 2;
        }
        return 0;
    }

    method !size-of-pseudo($node, %env) {
        my $current_pc = %env<PC> // 0;
        given $node.mnemonic {
            when 'DB' {
                my $size = 0;
                for $node.operands -> $op {
                    my $val = self!eval-to-any($op, %env);
                    if $val ~~ Int {
                        $size += 1;
                    } elsif $val ~~ Str {
                        $size += $val.chars;
                    }
                }
                return $size;
            }
            when 'DW' { return $node.operands.elems * 2; }
            when 'DD' { return $node.operands.elems * 4; }
            when 'RESB' {
                return self!eval-to-int($node.operands[0], %env);
            }
            when 'ALIGNB' {
                my $boundary = self!eval-to-int($node.operands[0], %env);
                return ($boundary - ($current_pc % $boundary)) % $boundary;
            }
        }
        return 0;
    }

    method !eval-to-int($op, %env) {
        my $res = self!eval-to-any($op, %env);
        return $res if $res ~~ Int;
        return 0;
    }

    method !eval-to-any($op, %env) {
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
