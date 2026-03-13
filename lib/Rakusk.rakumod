use v6;
unit module Rakusk;
use JSON::Fast;

# 1. 外部データの読み込み（デフォルトパス）
our $DEFAULT_INST_PATH = "data/instructions.json";

class AssemblerActions {
    has %.REGS;
    has %.INST;

    submethod TWEAK() {
        # 初期化時にJSONからデータを読み込む
        my $data = from-json($DEFAULT_INST_PATH.IO.slurp);
        %!REGS = $data<registers>;
        %!INST = $data<instructions>;
    }

    method TOP($/) {
        make Buf.new($<line>».made.grep(*.defined).map(*.list).flat);
    }

    method line($/) {
        make $<statement> ?? $<statement>.made !! Nil;
    }

    method statement($/) {
        if $<mnemonic_stmt> { make $<mnemonic_stmt>.made }
        elsif $<opcode_stmt> { make $<opcode_stmt>.made }
        else { make Nil }
    }

    method opcode_stmt($/) {
        my $m = $<mnemonic_op_none>.uc;
        my $info = %!INST{$m};
        make Buf.new($info<opcode>.parse-base(16));
    }

    method mnemonic_stmt($/) {
        my $m = $<mnemonic_op_req>.uc;
        my $info = %!INST{$m};
        
        if $info<type> eq 'reg-imm8' {
            my $ops = $<operand_list><operand>;
            my $reg_name = $ops[0]<reg>.uc;
            my $imm_str  = $ops[1]<imm>.Str;
            my $imm_val  = $imm_str.starts-with('0x', :i) 
                           ?? $imm_str.substr(2).parse-base(16) 
                           !! $imm_str.parse-base(10);
            
            my $opcode = $info<base_opcode>.parse-base(16) + %!REGS{$reg_name};
            make Buf.new($opcode, $imm_val);
        }
    }
}

# 文法定義を動的に生成するためのヘルパー
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

our sub assemble(Str $code) is export {
    my $actions = AssemblerActions.new;
    my $match = Assembler.parse($code, :$actions);
    return $match ?? $match.made !! Nil;
}