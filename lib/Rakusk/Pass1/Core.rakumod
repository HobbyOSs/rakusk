use Rakusk::Log;
use Rakusk::AST;
use Rakusk::Pass1::Instruction;
use Rakusk::Pass1::Pseudo;
use Rakusk::Pass1::Statement;

unit class Rakusk::Pass1::Core does Rakusk::Pass1::Instruction does Rakusk::Pass1::Pseudo does Rakusk::Pass1::Statement;

has %.symbols;
has @.ast;
has Int $.pc is rw = 0;
has Int $.bit_mode is rw = 16;
has @.global_symbols is rw = [];
has @.extern_symbols is rw = [];
has Str $.output_format is rw = "binary";
has Str $.source_file_name is rw = "";
has @.sections is rw = [];
has Str $.current_section is rw = ".text";

method evaluate(@ast, %regs) {
    @!ast = @ast;
    
    # パス1: ラベル・定数の収集とPCの計算
    $!pc = 0;
    # bit_mode は初期化せず、コンストラクタで渡された値（またはデフォルト）を維持する
    @!global_symbols = [];
    @!extern_symbols = [];

    for @!ast -> $node {
        my %env = symbols => %!symbols, PC => $!pc;

        if $node ~~ LabelStmt | DeclareStmt | ConfigStmt {
            self.process-statement($node, %regs, %env);
        } elsif $node ~~ InstructionNode {
            self.process-instruction($node, %regs, %env);
        } elsif $node ~~ PseudoNode {
            self.process-pseudo($node, %env);
        } elsif $node ~~ ExportSymStmt {
            self.global_symbols.append($node.symbols);
        } elsif $node ~~ ExternSymStmt {
            self.extern_symbols.append($node.symbols);
        }
    }
    return self;
}
