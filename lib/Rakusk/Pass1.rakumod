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
                $!pc = $node.operands[0];
                next;
            }

            # 動的なオペランド（$など）の解決
            if $node.can('operands') {
                for $node.operands.kv -> $i, $op {
                    if $op eq '$' {
                        $node.operands[$i] = $!pc;
                    }
                    elsif %!symbols{$op}:exists {
                        $node.operands[$i] = %!symbols{$op};
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