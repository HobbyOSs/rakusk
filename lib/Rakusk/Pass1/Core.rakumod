use v6;
use Rakusk::AST;
use Rakusk::Pass1::Instruction;
use Rakusk::Pass1::Pseudo;
use Rakusk::Pass1::Statement;

unit class Rakusk::Pass1::Core does Rakusk::Pass1::Instruction does Rakusk::Pass1::Pseudo does Rakusk::Pass1::Statement;

has %.symbols;
has @.ast;
has Int $.pc is rw = 0;
has Int $.bit_mode is rw = 16;
has @.global_symbols;
has @.extern_symbols;

method evaluate(@ast, %regs) {
    @!ast = @ast;
    
    # パス1: ラベル・定数の収集とPCの計算
    $!pc = 0;
    $!bit_mode = 16;
    @!global_symbols = [];
    @!extern_symbols = [];

    for @!ast -> $node {
        my %env = symbols => %!symbols, PC => $!pc;

        if $node ~~ LabelStmt | DeclareStmt | ConfigStmt {
            self.process-statement($node, %regs, %env);
        }
        elsif $node ~~ InstructionNode {
            self.process-instruction($node, %regs, %env);
        }
        elsif $node ~~ PseudoNode {
            self.process-pseudo($node, %env);
        }
    }
    return self;
}