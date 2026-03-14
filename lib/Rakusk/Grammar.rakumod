use v6;
unit module Rakusk::Grammar;
use JSON::Fast;
use Rakusk::AST;

# 1. 外部データの読み込み
our $DEFAULT_INST_PATH = "data/instructions.json";
my $data = from-json($DEFAULT_INST_PATH.IO.slurp);
my %INST_DATA = $data<instructions>;
my %REGS_DATA = $data<registers>;

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
        | <label_stmt> <.ws> [ <mnemonic_stmt> | <opcode_stmt> ]?
        | <declare_stmt>
        | <export_sym_stmt>
        | <extern_sym_stmt>
        | <config_stmt>
        | <mnemonic_stmt>
        | <opcode_stmt>
        ]
        [ \n | $ ]
    }

    # 基本要素
    token ident { <[a..zA..Z$_]> <[a..zA..Z$_0..9]>* }
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
                | AL|CL|DL|BL|AH|CH|DH|BH ] }

    # 文の定義
    rule label_stmt { <label> }
    rule declare_stmt { <ident> 'EQU' <exp> }
    rule export_sym_stmt { 'GLOBAL' <ident> [ ',' <ident> ]* }
    rule extern_sym_stmt { 'EXTERN' <ident> [ ',' <ident> ]* }
    rule config_stmt { '[' <config_type> <exp> ']' }
    token config_type { :i BITS|INSTRSET|OPTIMIZE|FORMAT|PADDING|PADSET|SECTION|ABSOLUTE|FILE }

    rule mnemonic_stmt { <mnemonic_op_any> <operand_list> }
    token opcode_stmt { <mnemonic_op_any> }
    token mnemonic_op_any { 
        | :i @( %INST_DATA.keys.sort({ $^b.chars <=> $^a.chars }) )
        | <ident>
    }

    rule operand_list { <operand> [ ',' <operand> ]* }
    token operand { <exp> }

    # 式（二項演算の優先順位は簡略化）
    rule exp { <term> [ <op> <term> ]* }
    token op { <[ + \- * / % ]> }
    rule term {
        | <factor>
        | '(' <exp> ')'
    }

    token factor {
        | <reg>
        | <addressing>
        | <hex_lit>
        | <num_lit>
        | <ident>
        | <string_lit>
        | '$'
    }

    rule addressing {
        '['
        [ <base=reg> | <base=ident> ]?
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

class AssemblerActions is export {
    method TOP($/) {
        make $<statement>».made.grep(*.defined);
    }

    method statement($/) {
        if $<label_stmt> {
            my $label = $<label_stmt>.made;
            if $<mnemonic_stmt> {
                make [$label, $<mnemonic_stmt>.made];
            } elsif $<opcode_stmt> {
                make [$label, $<opcode_stmt>.made];
            } else {
                make $label;
            }
        } else {
            make $/.values[0].made;
        }
    }

    method label_stmt($/) {
        make LabelStmt.new(label => $<label><ident>.Str);
    }

    method declare_stmt($/) {
        make DeclareStmt.new(name => $<ident>.Str, value => $<exp>.made);
    }

    method export_sym_stmt($/) {
        make ExportSymStmt.new(symbols => $<ident>».Str);
    }

    method extern_sym_stmt($/) {
        make ExternSymStmt.new(symbols => $<ident>».Str);
    }

    method config_stmt($/) {
        make ConfigStmt.new(type => $<config_type>.Str.uc, value => $<exp>.made);
    }

    method opcode_stmt($/) {
        my $m = $<mnemonic_op_any>.uc;
        make InstructionNode.new(mnemonic => $m, info => %INST_DATA{$m});
    }

    method mnemonic_stmt($/) {
        my $m = $<mnemonic_op_any>.uc;
        my $info = %INST_DATA{$m};
        my @ops = $<operand_list>.made;
        if $info && $info<type> eq 'pseudo' {
            make PseudoNode.new(mnemonic => $m, operands => @ops);
        } else {
            make InstructionNode.new(mnemonic => $m, operands => @ops, info => $info // {});
        }
    }

    method operand_list($/) { make $<operand>».made; }
    method operand($/) { make $<exp>.made; }
    method exp($/) {
        my $res = $<term>[0].made;
        # TODO: 演算の実装（現在は最初の一つのみ）
        make $res;
    }
    method term($/) {
        make $<factor> ?? $<factor>.made !! $<exp>.made;
    }
    method factor($/) {
        if $<reg> {
            make $<reg>.made;
        }
        elsif $<addressing> {
            make $<addressing>.made;
        }
        elsif $<hex_lit> {
            make Immediate.new(value => $<hex_lit>.Str.substr(2).parse-base(16));
        }
        elsif $<num_lit> {
            make Immediate.new(value => $<num_lit>.Int);
        }
        elsif $<string_lit> {
            make Immediate.new(value => $<string_lit>.Str);
        }
        elsif $<ident> {
            # identifier can be a register (if not matched by <reg> yet) or a symbol
            # but usually <reg> matches first if it's a register.
            make Immediate.new(value => $<ident>.Str);
        }
        elsif $/ eq '$' {
            make Immediate.new(value => '$');
        }
    }

    method addressing($/) {
        my $base;
        if $<base> {
            if $<base>.made ~~ Register {
                $base = $<base>.made;
            } else {
                $base = $<base>.Str; # symbol
            }
        }

        my $index;
        my $scale = 1;
        my $disp = 0;

        # 非常に簡易的な実装（複数の項を順番に処理）
        # 本来はもっと厳密なパースが必要だが、まずは基本的なケースをカバー
        for $/.caps -> $cap {
            if $cap.key eq 'index' {
                $index = Register.new(name => $cap.value.Str.uc);
            }
            elsif $cap.key eq 'scale' {
                $scale = $cap.value.Int;
            }
            elsif $cap.key eq 'disp' {
                # TODO: +- を考慮
                $disp = $cap.value.made;
            }
        }
        
        # 実際にはもっと複雑なので、一旦単純化して再設計
        # rule addressing の構造に合わせて取得
        my $mem = Memory.new(base => $base);
        if $<index> {
            # index is a list because of [...]? and rule structure
            $mem.index = $<index>[0].made;
            $mem.scale = $<scale>[0].Int if $<scale>;
        }
        if $<disp> {
            $mem.disp = $<disp>[0].made;
        }

        make $mem;
    }

    method reg($/) {
        make Register.new(name => $/.Str.uc);
    }
}
