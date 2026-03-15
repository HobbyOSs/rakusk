use v6;
use Rakusk::AST;
use Rakusk::Util;
use Rakusk::Pass2::Instruction;
use Rakusk::Pass2::Pseudo;
use Rakusk::Pass2::Statement;
use Rakusk::FileFmt::COFF;
use Rakusk::Log;

unit class Rakusk::Pass2::Core does Rakusk::Pass2::Instruction does Rakusk::Pass2::Pseudo does Rakusk::Pass2::Statement does Rakusk::FileFmt::COFF;

has @.ast;
has Buf $.output is rw = Buf.new();
has Int $.bit_mode is rw = 16;
has Str $.output_format is rw = "binary";
has Str $.source_file_name is rw = "";
has @.global_symbols = [];
has @.extern_symbols = [];
has @.listing;

method assemble(%regs, %symbols = {}) {
    my $pc = 0;
    # bit_mode はコンストラクタで渡された値を初期値とする
    $!output = Buf.new();
    @!listing = [];
    for @!ast -> $node {
        if $node ~~ PseudoNode && $node.mnemonic eq 'ORG' {
            my $val = $node.operands[0];
            $pc = self.eval-to-int($val, { symbols => %symbols, PC => $pc });
            @!listing.push({ :$node, :$pc, :type<pseudo> });
            next;
        }
        if $node ~~ ConfigStmt && $node.type eq 'BITS' {
            $!bit_mode = self.eval-to-int($node.value, { symbols => %symbols, PC => $pc });
            @!listing.push({ :$node, :$pc, :type<config> });
            next;
        }
        if $node ~~ PseudoNode && $node.mnemonic eq 'BITS' {
            $!bit_mode = self.eval-to-int($node.operands[0], { symbols => %symbols, PC => $pc });
            @!listing.push({ :$node, :$pc, :type<pseudo> });
            next;
        }

        my %env = symbols => %symbols, PC => $pc, strict_eval => True;
        my $bin = self.encode-node($node, %regs, %env);

        if $bin.defined {
            my $type = do given $node {
                when InstructionNode { $node.info<type> // 'unknown' }
                when PseudoNode { 'pseudo' }
                default { 'unknown' }
            };
            @!listing.push({ :$node, :$bin, :$pc, :$type, :size($bin.elems) });
            $!output ~= $bin;
            $pc += $bin.elems;
        } else {
            @!listing.push({ :$node, :$pc });
        }
    }

    if $!output_format.uc eq 'WCOFF' {
        my $bin = self.wrap-wcoff(%symbols, $!output, $!source_file_name, @!global_symbols, @!extern_symbols);
        return { output => $bin, :@!listing };
    }

    return { :$!output, :@!listing };
}

method encode-node($node, %regs, %env) {
    if $node ~~ InstructionNode {
        return self.encode-instruction($node, %regs, %env);
    } elsif $node ~~ PseudoNode {
        return self.encode-pseudo($node, %env);
    }
    return Buf.new();
}
