use v6;
unit module Rakusk::Pass2;
use Rakusk::AST;

class Pass2 is export {
    has @.ast;
    has Buf $.output = Buf.new();

    method assemble(%regs) {
        my $pc = 0;
        for @!ast -> $node {
            if $node ~~ PseudoNode && $node.mnemonic eq 'ORG' {
                $pc = $node.operands[0];
                next;
            }

            my $bin;
            if $node ~~ InstructionNode {
                $bin = $node.encode(%regs);
            }
            elsif $node ~~ PseudoNode {
                $bin = $node.encode($pc);
            }

            if $bin.defined {
                $!output ~= $bin;
                $pc += $bin.elems;
            }
        }
        return $!output;
    }
}