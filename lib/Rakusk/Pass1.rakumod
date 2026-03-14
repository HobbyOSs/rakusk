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

            # 動的なオペランド（$など）の解決
            if $node.can('operands') {
                my @ops := $node.operands;
                for @ops.kv -> $i, $op {
                    # $op が Operand (Register, Immediate) の場合
                    my $val = $op ~~ Str ?? $op !! $op.Str;
                    if $val eq '$' {
                        @ops[$i] = Rakusk::AST::Immediate.new(value => $!pc);
                    }
                    elsif %!symbols{$val}:exists {
                        my $sym_val = %!symbols{$val};
                        @ops[$i] = $sym_val ~~ Rakusk::AST::Immediate ?? $sym_val !! Rakusk::AST::Immediate.new(value => $sym_val);
                    }
                }
            }

            if $node ~~ InstructionNode {
                $!pc += $node.encode(%regs).elems;
            }
            elsif $node ~~ PseudoNode {
                $!pc += $node.encode($!pc).elems;
            }
        }
        return self;
    }
}