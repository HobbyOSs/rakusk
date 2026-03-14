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
                $!pc += $node.encode(%regs, %env).elems;
            }
            elsif $node ~~ PseudoNode {
                $!pc += $node.encode(%env).elems;
            }
        }
        return self;
    }
}