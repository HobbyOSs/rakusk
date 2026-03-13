use v6;
unit module Rakusk::Grammar;
use JSON::Fast;

# 1. 外部データの読み込み（デフォルトパス）
our $DEFAULT_INST_PATH = "data/instructions.json";

# 文法定義を動的に生成するためのデータ準備
my $data = from-json($DEFAULT_INST_PATH.IO.slurp);
my @inst_with_ops = $data<instructions>.grep({ .value<type> ne 'no-op' }).map(*.key).sort({ $^b.chars <=> $^a.chars });
my @inst_no_ops   = $data<instructions>.grep({ .value<type> eq 'no-op' }).map(*.key).sort({ $^b.chars <=> $^a.chars });
my %REGS_DATA     = $data<registers>;

grammar Assembler is export {
    token TOP { ^ <line>* $ }

    token line {
        | <ws_only>+ [ \n | $ ]
        | \n
        | <statement>
    }

    token statement {
        <ws_only>*
        [
        | <mnemonic_stmt>
        | <opcode_stmt>
        | <comment>
        | <empty>
        ]
        <ws_only>*
        [ \n | $ ]
        <?{ $/.chars > 0 }>
    }

    token mnemonic_stmt {
        <mnemonic_op_req> \s+ <operand_list>
    }

    token opcode_stmt {
        <mnemonic_op_none>
    }

    token mnemonic_op_req  { :i @( @inst_with_ops ) }
    token mnemonic_op_none { :i @( @inst_no_ops ) }

    token operand_list {
        <operand> [ \s* ',' \s* <operand> ]*
    }

    token operand { <reg> | <imm> }
    token reg     { :i @( %REGS_DATA.keys.sort({ $^b.chars <=> $^a.chars }) ) }
    token imm     { :i [ '0x' <[0..9a..f]>+ | <[0..9]>+ ] }

    token comment { ';' \N* }
    token ws_only { <[ \t ]> }
    token empty   { <?> }
}