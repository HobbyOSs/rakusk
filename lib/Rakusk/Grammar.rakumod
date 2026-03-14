use v6;
unit module Rakusk::Grammar;
use JSON::Fast;
use Rakusk::AST;

# 1. 外部データの読み込み
our $DEFAULT_INST_PATH = "data/instructions.json";
my $data = from-json($DEFAULT_INST_PATH.IO.slurp);
my %INST_DATA = $data<instructions>;
my %REGS_DATA = $data<registers>;

# ニーモニックから命令定義へのマップ（複数のバリアントを保持可能）
my %MNEMONIC_MAP;
for %INST_DATA.kv -> $key, $val {
    my $m = $val<mnemonic> // $key;
    %MNEMONIC_MAP{$m.uc}.push($val);
}

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
        | :i @( %MNEMONIC_MAP.keys.sort({ $^b.chars <=> $^a.chars }) )
        | <ident>
    }

    rule operand_list { <operand> [ ',' <operand> ]* }
    token operand { <exp> }

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
        | <ident>
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
        my @variants = |(%MNEMONIC_MAP{$m} // []);
        my $info = @variants.elems > 0 ?? @variants[0] !! {};
        make InstructionNode.new(mnemonic => $m, info => $info);
    }

    method mnemonic_stmt($/) {
        my $m = $<mnemonic_op_any>.uc;
        my @variants = |(%MNEMONIC_MAP{$m} // []);
        my @ops = $<operand_list>.made;

        my $info = self!select-variant($m, @variants, @ops);

        if $info && $info<type> eq 'pseudo' {
            make PseudoNode.new(mnemonic => $m, operands => @ops);
        } else {
            make InstructionNode.new(mnemonic => $m, operands => @ops, info => $info // {});
        }
    }

    method !select-variant($mnemonic, @variants, @ops) {
        return {} if @variants.elems == 0;
        return @variants[0] if @variants.elems == 1;

        for @variants -> $v {
            if self!match-variant($v, @ops) {
                return $v;
            }
        }
        return @variants[0];
    }

    method !match-variant($v, @ops) {
        my $type = $v<type> // '';
        given $type {
            when 'reg-reg' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Register;
            }
            when 'reg-imm8' | 'reg-imm16' | 'reg-imm32' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Immediate;
            }
            when 'no-op' {
                return @ops.elems == 0;
            }
        }
        return False;
    }

    method operand_list($/) { make $<operand>».made; }
    method operand($/) {
        my $made = $<exp>.made;
        if $made ~~ Expression {
            make Immediate.new(expr => $made);
        } else {
            make $made;
        }
    }

    method exp($/) {
        my $head = $<mult_exp>[0].made;
        if $<add_op> {
            make AddExp.new(
                head => $head,
                operators => $<add_op>».Str,
                tails => $<mult_exp>[1..*]».made
            );
        } else {
            make $head;
        }
    }

    method mult_exp($/) {
        my $head = $<term>[0].made;
        if $<mult_op> {
            make MultExp.new(
                head => $head,
                operators => $<mult_op>».Str,
                tails => $<term>[1..*]».made
            );
        } else {
            make $head;
        }
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
        else {
            my $factor;
            if $<hex_lit> {
                $factor = HexFactor.new(value => $<hex_lit>.Str);
            }
            elsif $<num_lit> {
                $factor = NumberFactor.new(value => $<num_lit>.Int);
            }
            elsif $<string_lit> {
                my $s = $<string_lit>.Str;
                if $/.Str.starts-with("'") {
                    if $s.chars == 1 {
                        $factor = CharFactor.new(value => $s);
                    } else {
                        $factor = StringFactor.new(value => $s);
                    }
                } else {
                    $factor = StringFactor.new(value => $s);
                }
            }
            elsif $<ident> {
                $factor = IdentFactor.new(value => $<ident>.Str);
            }
            elsif $/.Str eq '$' {
                $factor = IdentFactor.new(value => '$');
            }

            if $factor {
                make ImmExp.new(factor => $factor);
            }
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
        } else {
            # disp が無い場合は 0 (NumberExp) を入れておく
            $mem.disp = NumberExp.new(value => 0);
        }

        make $mem;
    }

    method reg($/) {
        make Register.new(name => $/.Str.uc);
    }
}
