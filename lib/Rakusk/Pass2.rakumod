use v6;
unit module Rakusk::Pass2;
use Rakusk::AST;
use Rakusk::Pass1;

class Pass2 is export {
    has Pass1 $.pass1;
    has Buf $.output = Buf.new();

    method assemble(%regs) {
        for $!pass1.ast -> $node {
            if $node ~~ InstructionNode {
                $!output ~= $node.encode(%regs);
            }
        }
        return $!output;
    }
}

our sub pass2(@ast, %regs) is export {
    my $bin = Buf.new();
    for @ast -> $node {
        if $node ~~ InstructionNode {
            $bin ~= $node.encode(%regs);
        }
    }
    return $bin;
}
