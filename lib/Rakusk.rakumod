use v6;
unit module Rakusk;
use Rakusk::Grammar;
use Rakusk::Pass1;
use Rakusk::Pass2;
use JSON::Fast;
use Rakusk::Log;
use Rakusk::Util;

class AssembledResult is export {
    has Buf $.binary;
    has @.listing;
    has %.symbols;
}

our sub assemble(Str $source) is export {
    # 1. データの読み込み
    my %regs = %Rakusk::Util::REGS_DATA;

    # 2. Parse (AST構築)
    my $actions = AssemblerActions.new();
    my $match = Assembler.parse($source, :$actions);
    unless $match {
        die "Syntax error in assembly source";
    }
    my @ast = $match.made;
    my $bit_mode = $actions.bit_mode;

    # 3. Pass 1 (シンボル解決とPC計算)
    my $pass1 = Pass1.new(:$bit_mode).evaluate(@ast, %regs);

    # 4. Pass 2 (バイナリ生成)
    my $pass2 = Pass2.new(
        ast => $pass1.ast,
        bit_mode => $pass1.bit_mode,
        output_format => $pass1.output_format,
        source_file_name => $pass1.source_file_name,
        global_symbols => $pass1.global_symbols,
        extern_symbols => $pass1.extern_symbols,
        symbol_order => $pass1.symbol_order,
    );
    my $res = $pass2.assemble(%regs, $pass1.symbols);
    
    return AssembledResult.new(
        binary => $res<output>,
        listing => |$res<listing>,
        symbols => $pass1.symbols
    );
}
