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
has @.symbol_order is rw = [];
has Str $.output_format is rw = "binary";
has Str $.source_file_name is rw = "";
has @.sections is rw = [];
has Str $.current_section is rw = ".text";

method evaluate(@ast, %regs) {
    @!ast = @ast;

    # 1. AST内の全ジャンプ命令の $.current_size を 2 にリセット（初回パスの楽観的初期化）
    for @!ast -> $node {
        if $node ~~ InstructionNode && ($node.mnemonic eq 'JMP' || $node.mnemonic ~~ /^ J/ || $node.mnemonic eq 'CALL') {
            $node.current_size = 2;
        }
    }
    
    # マルチパス最適化（BDO）のループ
    my $changed = True;
    my $pass_count = 0;
    my $max_passes = 100;

    while $changed && $pass_count < $max_passes {
        $changed = False;
        $pass_count++;
        $!pc = 0;
        
        # bit_mode は初期化せず、コンストラクタで渡された値（またはデフォルト）を維持する
        @!global_symbols = [];
        @!extern_symbols = [];
        @!symbol_order = [];

        for @!ast -> $node {
            my %env = symbols => %!symbols, PC => $!pc;

            if $node ~~ LabelStmt | DeclareStmt | ConfigStmt {
                self.process-statement($node, %regs, %env);
            } elsif $node ~~ InstructionNode {
                my $old_size = $node.current_size;
                self.process-instruction($node, %regs, %env);
                if $node.current_size > $old_size {
                    $changed = True;
                }
            } elsif $node ~~ PseudoNode {
                self.process-pseudo($node, %env);
            } elsif $node ~~ ExportSymStmt {
                self.global_symbols.append($node.symbols);
                self.symbol_order.append($node.symbols);
            } elsif $node ~~ ExternSymStmt {
                self.extern_symbols.append($node.symbols);
                self.symbol_order.append($node.symbols);
            }
        }
    }
    
    say "DEBUG: Pass 1 completed in $pass_count passes" if %*ENV<RAKUSK_DEBUG>;
    return self;
}
