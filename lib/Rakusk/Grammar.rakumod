use v6;
unit module Rakusk::Grammar;
use JSON::Fast;
use Rakusk::AST;

# 1. 外部データの読み込み（デフォルトパス）
our $DEFAULT_INST_PATH = "data/instructions.json";

# 文法定義を動的に生成するためのデータ準備
my $data = from-json($DEFAULT_INST_PATH.IO.slurp);
my @inst_with_ops = $data<instructions>.grep({ .value<type> ne 'no-op' }).map(*.key).sort({ $^b.chars <=> $^a.chars });
my @inst_no_ops   = $data<instructions>.grep({ .value<type> eq 'no-op' }).map(*.key).sort({ $^b.chars <=> $^a.chars });
my %REGS_DATA     = $data<registers>;
my %INST_DATA     = $data<instructions>;

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

    token operand { <reg> | <imm> | <string_lit> | <symbol_pc> }
    token reg     { :i @( %REGS_DATA.keys.sort({ $^b.chars <=> $^a.chars }) ) }
    token imm     { :i [ '-'? '0x' <[0..9a..f]>+ | '-'? <[0..9]>+ ] }
    token string_lit {
        | '"' <( [ [ \\ . ] | <-[ " ]> ]* )> '"'
        | "'" <( [ [ \\ . ] | <-[ ' ]> ]* )> "'"
    }
    token symbol_pc { '$' }

    token comment { ';' \N* }
    token ws_only { <[ \t ]> }
    token empty   { <?> }
}

class AssemblerActions is export {
    method TOP($/) {
        make $<line>».made.grep(*.defined);
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
        my $info = %INST_DATA{$m};
        make InstructionNode.new(
            mnemonic => $m,
            info     => $info
        );
    }

    method mnemonic_stmt($/) {
        my $m = $<mnemonic_op_req>.uc;
        my $info = %INST_DATA{$m};
        
        if $info<type> eq 'reg-imm8' {
            my @ops = $<operand_list><operand>;
            my $reg_name = @ops[0]<reg>.uc;
            my $imm_val  = self.parse-imm(@ops[1]<imm>);
            
            make InstructionNode.new(
                mnemonic => $m,
                operands => [$reg_name, $imm_val],
                info     => $info
            );
        }
        elsif $info<type> eq 'pseudo' {
            my @ops_nodes = $<operand_list><operand>;
            my @operands;
            for @ops_nodes -> $op_node {
                if $op_node<imm> {
                    @operands.push(self.parse-imm($op_node<imm>));
                }
                elsif $op_node<string_lit> {
                    @operands.push($op_node<string_lit>.Str);
                }
                elsif $op_node<symbol_pc> {
                    @operands.push('$'); # プレースホルダとして保持
                }
            }
            make PseudoNode.new(
                mnemonic => $m,
                operands => @operands
            );
        }
    }

    method parse-imm($imm_match) {
        my $str = $imm_match.Str;
        my $sign = 1;
        if $str.starts-with('-') {
            $sign = -1;
            $str = $str.substr(1);
        }

        if $str.starts-with('0x', :i) {
            return $sign * $str.substr(2).parse-base(16);
        }
        else {
            return $sign * $str.parse-base(10);
        }
    }
}