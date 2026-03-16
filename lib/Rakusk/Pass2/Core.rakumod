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
has @.symbol_order = [];
has @.relocations = [];
has @.listing;

method assemble(%regs, %symbols = {}) {
    my $pc = 0;
    @!relocations = [];
    # bit_mode はコンストラクタで渡された値を初期値とする
    $!output = Buf.new();
    @!listing = [];
    for @!ast -> $node {
        if $node ~~ ConfigStmt && $node.type eq 'ORG' {
            my $val = $node.value;
            $pc = self.eval-to-int($val, { symbols => %symbols, PC => $pc });
            @!listing.push({ :$node, :$pc, :type<config> });
            next;
        }
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

        my %env = symbols => %symbols, PC => $pc, strict_eval => True, relocations => @!relocations;
        my $bin = self.encode-node($node, %regs, %env);

        if $bin.defined {
            say "DEBUG: PC=$pc mnemonic=" ~ ($node ~~ InstructionNode ?? $node.mnemonic !! 'pseudo') ~ " size=" ~ $bin.elems ~ " hex=" ~ $bin.list.fmt("%02x", " ") if %*ENV<RAKUSK_DEBUG>;
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
        # relocations が重複して登録されている可能性があるため、Pass2開始時にクリアするか、ここで整理する
        # 現状、Instruction.rakumod で直接 @!relocations に push している
        my $bin = self.wrap-wcoff(%symbols, $!output, $!source_file_name, @!global_symbols, @!extern_symbols, @!relocations, @!symbol_order);
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
