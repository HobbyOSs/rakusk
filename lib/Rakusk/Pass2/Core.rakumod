use v6;
use Rakusk::AST;
use Rakusk::Util;
use Rakusk::Pass2::Instruction;
use Rakusk::Pass2::Pseudo;
use Rakusk::Pass2::Statement;

unit class Rakusk::Pass2::Core does Rakusk::Pass2::Instruction does Rakusk::Pass2::Pseudo does Rakusk::Pass2::Statement;

has @.ast;
has Buf $.output is rw = Buf.new();

method assemble(%regs, %symbols = {}) {
    my $pc = 0;
    $!output = Buf.new();
    for @!ast -> $node {
        if $node ~~ PseudoNode && $node.mnemonic eq 'ORG' {
            my $val = $node.operands[0];
            $pc = self.eval-to-int($val, { symbols => %symbols, PC => $pc });
            next;
        }

        my %env = symbols => %symbols, PC => $pc;
        my $bin = self.encode-node($node, %regs, %env);

        if $bin.defined {
            $!output ~= $bin;
            $pc += $bin.elems;
        }
    }
    return $!output;
}

method encode-node($node, %regs, %env) {
    if $node ~~ InstructionNode {
        return self.encode-instruction($node, %regs, %env);
    }
    elsif $node ~~ PseudoNode {
        return self.encode-pseudo($node, %env);
    }
    return Buf.new();
}