use v6;
unit module Rakusk::Pass2;
use Rakusk::AST;

our sub pass2(@ast, %regs) is export {
    my $bin = Buf.new();
    for @ast -> $node {
        if $node ~~ InstructionNode {
            $bin ~= $node.encode(%regs);
        }
    }
    return $bin;
}