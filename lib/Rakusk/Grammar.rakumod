use v6;
unit module Rakusk::Grammar;
use JSON::Fast;
use Rakusk::AST;
use Rakusk::Util;
use Rakusk::Log;

# 1. 外部データの読み込み
# Rakusk::Util からインポートされる %INST_DATA, %REGS_DATA を使用

# ニーモニックから命令定義へのマップ（複数のバリアントを保持可能）
our %MNEMONIC_MAP;

sub init-grammar-data() {
    return if %MNEMONIC_MAP.elems > 0;
    for %INST_DATA.kv -> $key, $val {
        my $m = $val<mnemonic> // $key;
        %MNEMONIC_MAP{$m.uc} //= [];
        %MNEMONIC_MAP{$m.uc}.push($val);
    }

    # バリアントの優先順位付け: 特殊な（短い）命令を優先する
    for %MNEMONIC_MAP.kv -> $m, $variants {
        %MNEMONIC_MAP{$m} = [ $variants.sort({
                # 優先度スコア: 低いほど優先
                my $v_a = $^a;
                my $v_b = $^b;
                my $score_a = do {
                    my $type = $v_a<type> // '';
                    if $type eq 'pseudo' { 0 }
                    elsif $type eq 'short-imm' { 1 }
                    elsif $type eq 'short-jump' { 2 }
                    elsif $type ~~ /moffs/ { 3 }
                    elsif $v_a<base_opcode> { 4 }
                    else { 5 }
                };
                my $score_b = do {
                    my $type = $v_b<type> // '';
                    if $type eq 'pseudo' { 0 }
                    elsif $type eq 'short-imm' { 1 }
                    elsif $type eq 'short-jump' { 2 }
                    elsif $type ~~ /moffs/ { 3 }
                    elsif $v_b<base_opcode> { 4 }
                    else { 5 }
                };
                $score_a <=> $score_b;
        }) ];
    }
}

# ロード時に初期化
init-grammar-data();

grammar Assembler is export {
    # 既存の ws をオーバーライドして、コメントも空白として扱う
    # ただし改行は文の区切りとして重要なので含めない
    token ws {
        [ <[ \t ]> | " " | <comment> ]*
    }
    token comment { [ ';' | '#' ] \N* }

    token TOP {
        ^ <.ws> [ <statement> | \n+ <.ws> ]* $
    }

    # 各文は改行またはファイル末尾で終わる
    rule statement {
        [
            || <label_stmt> <instruction_or_directive>?
            || <instruction_or_directive>
            || <.comment>
        ]
        [ \n | $ ]
    }

    rule instruction_or_directive {
        || <declare_stmt>
        || <export_sym_stmt>
        || <extern_sym_stmt>
        || <config_stmt>
        || <org_stmt>
        || <db_stmt>
        || <mnemonic_stmt>
        || <opcode_stmt>
    }

    rule org_stmt { :i 'ORG' <exp> }
    rule db_stmt { :i [ 'DB' | 'DW' | 'DD' | 'RESB' ] <operand_list> }

    # 基本要素
    token ident { <[a..zA..Z$_.]> <[a..zA..Z$_0..9.]>* }
    token label { <ident> ':' }
    token num_lit { '-'? \d+ }
    token hex_lit { :i 0x <[0..9a..fA..F]>+ }
    token string_lit {
        | '"' <( [ [ \\ . ] | <-[ " ]> ]* )> '"'
        | "'" <( [ [ \\ . ] | <-[ ' ]> ]* )> "'"
    }
    token reg { :i [ RAX|RBX|RCX|RDX|RSI|RDI|RBP|RSP|R8|R9|R10|R11|R12|R13|R14|R15
            | EAX|EBX|ECX|EDX|ESI|EDI|EBP|ESP
            | AX|BX|CX|DX|SI|DI|BP|SP
            | AL|CL|DL|BL|AH|CH|DH|BH
            | ES|CS|SS|DS|FS|GS
            | CR0|CR2|CR3|CR4 ] <|w> }

    # 文の定義
    rule label_stmt { <label> }
    rule declare_stmt { <ident_not_reserved> 'EQU' <exp> }
    rule export_sym_stmt { 'GLOBAL' <ident> [ ',' <ident> ]* }
    rule extern_sym_stmt { 'EXTERN' <ident> [ ',' <ident> ]* }
    rule config_stmt { '[' <config_type> <exp> ']' }
    token config_type { :i BITS|INSTRSET|OPTIMIZE|FORMAT|PADDING|PADSET|SECTION|ABSOLUTE|FILE }

    rule mnemonic_stmt { <mnemonic_op_any> <operand_list> }
    token opcode_stmt { <mnemonic_op_any> <|w> }
    token mnemonic_op_any {
        <!before :i [ ORG | DB | DW | DD | RESB ] <|w>>
        [
            | :i @( %MNEMONIC_MAP.keys.sort({ $^b.chars <=> $^a.chars }) )
            | <mnemonic_ident>
        ]
        <|w>
    }
    token mnemonic_ident {
        <!before '.'>
        <!before :i [ EQU|GLOBAL|EXTERN|BYTE|WORD|DWORD|FAR ] <|w>>
        <ident>
    }
    token ident_not_reserved {
        <!before :i [ EQU|GLOBAL|EXTERN|BYTE|WORD|DWORD|FAR|ORG|DB|DW|DD|RESB ] <|w>>
        <ident>
    }

    rule operand_list { <operand> [ ',' <operand> ]* }
    rule operand {
        | <size_prefix>? <sel=exp> ':' <off=exp>
        | <size_prefix>? <single=exp>
    }
    token size_prefix { :i [ BYTE|WORD|DWORD|FAR ] }

    # 式（二項演算の優先順位）
    rule exp { <mult_exp> [ <add_op> <mult_exp> ]* }
    token add_op { <[ + \- ]> }
    rule mult_exp { <term> [ <mult_op> <term> ]* }
    token mult_op { <[ * / % ]> }
    rule term {
        | <factor>
        | '(' <exp> ')'
    }

    token factor {
        | <reg>
        | <addressing>
        | <hex_lit>
        | <num_lit>
        | <string_lit>
        | <ident_not_reserved>
        | '$'
    }

    rule addressing {
        '['
            [ <base=reg> | <disp=exp> ]?
            [
                <.ws> <[ + \- ]> <.ws>
                [
                    | <index=reg> [ <.ws> '*' <.ws> <scale=num_lit> ]?
                    | <disp=exp>
                ]
            ]*
            ']'
    }
}
