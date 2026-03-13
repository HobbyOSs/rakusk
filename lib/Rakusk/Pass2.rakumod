use v6;
unit module Rakusk::Pass2;
use Rakusk::AST;
use Rakusk::Pass1;

class Pass2 is export {
    has Pass1 $.pass1;
    has Buf $.output = Buf.new();

    method assemble(%regs) {
        my $pc = 0;
        for $!pass1.ast -> $node {
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

our sub pass2(@ast, %regs) is export {
    my $bin = Buf.new();
    my $pc = 0;
    for @ast -> $node {
        if $node ~~ PseudoNode && $node.mnemonic eq 'ORG' {
            $pc = $node.operands[0];
            next;
        }

        my $chunk;
        if $node ~~ InstructionNode {
            $chunk = $node.encode(%regs);
        }
        elsif $node ~~ PseudoNode {
            $chunk = $node.encode($pc);
        }

        if $chunk.defined {
            $bin ~= $chunk;
            $pc += $chunk.elems;
        }
    }
    return $bin;
}
