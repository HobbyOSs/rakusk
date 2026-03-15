use v6;
unit module Rakusk::Grammar;
use JSON::Fast;
use Rakusk::AST;
use Rakusk::Util;
use Rakusk::Log;

# 1. 外部データの読み込み
# Rakusk::Util からインポートされる %INST_DATA, %REGS_DATA を使用

# ニーモニックから命令定義へのマップ（複数のバリアントを保持可能）
my %MNEMONIC_MAP;
for %INST_DATA.kv -> $key, $val {
    my $m = $val<mnemonic> // $key;
    %MNEMONIC_MAP{$m.uc} //= [];
    %MNEMONIC_MAP{$m.uc}.push($val);
}

# バリアントの優先順位付け: 特殊な（短い）命令を優先する
for %MNEMONIC_MAP.kv -> $m, $variants {
    %MNEMONIC_MAP{$m} = [ $variants.sort({
                # 優先度スコア: 低いほど優先
                # 1. pseudo (最優先)
                # 2. short-imm
                # 3. short-jump
                # 4. moffs (A0-A3)
                # 5. base_opcode を持つもの (MOV AX, imm 等)
                # 6. その他
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
            | AL|CL|DL|BL|AH|CH|DH|BH
            | ES|CS|SS|DS|FS|GS
            | CR0|CR2|CR3|CR4 ] }

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
        | <ident>
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

class AssemblerActions is export does Evaluator {
    has Int $.bit_mode is rw = 16;
    has %.symbols;

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
        my $name = $<ident>.Str;
        my $val_expr = $<exp>.made;
        my $node = DeclareStmt.new(name => $name, value => $val_expr);
        # パース中にシンボルを登録し、以降のバリアント選択で利用可能にする
        my $val = self.eval-to-any($val_expr, { symbols => %!symbols });
        %!symbols{$name} = $val if $val ~~ Int;
        make $node;
    }

    method export_sym_stmt($/) {
        make ExportSymStmt.new(symbols => $<ident>».Str);
    }

    method extern_sym_stmt($/) {
        make ExternSymStmt.new(symbols => $<ident>».Str);
    }

    method config_stmt($/) {
        my $type = $<config_type>.Str.uc;
        my $node = ConfigStmt.new(type => $type, value => $<exp>.made);
        if $type eq 'BITS' {
            $!bit_mode = self.eval-to-int($node.value, {});
        }
        make $node;
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

        # 特殊な最適化やバリアント選択の優先処理
        if self!try-special-variant($m, @variants, @ops, { symbols => %!symbols }) -> $special {
            make $special;
            return;
        }

        my $info = self!select-variant($m, @variants, @ops);

        if $info && ($info<type> // '') eq 'pseudo' {
            make PseudoNode.new(mnemonic => $m, operands => @ops);
        } else {
            my %final_info = $info ?? %$info !! { type => 'unknown' };
            if %final_info<type> eq 'unknown' {
                die "Error: No matching variant for mnemonic '$m' with operands [{@ops.map(*.Str).join(', ')}]";
            }
            make InstructionNode.new(mnemonic => $m, operands => @ops, info => %final_info);
        }
    }

    method !try-special-variant($m, @variants, @ops, %env) {
        # 1. JMP/CALL の絶対アドレス指定に対する near-jump 優先
        if $m eq 'JMP' | 'CALL' && @ops.elems == 1 && @ops[0] ~~ Immediate {
            my $ev = @ops[0].expr.eval({});
            # eval({}) for labels now returns the ImmExp object itself (self), not a NumberExp.
            # So this check only passes for numeric literals or symbols defined with EQU.
            if $ev ~~ NumberExp {
                my $near = @variants.grep({ ($_<type> // '') eq 'near-jump' })[0];
                return InstructionNode.new(mnemonic => $m, operands => @ops, info => $near) if $near;
            }
        }

        # 2. 算術演算での imm8 最適化 (83 /x ib 形式の優先)
        if $m ~~ /^(ADD|SUB|CMP|AND|OR|XOR|ADC|SBB)$/ && @ops.elems == 2 && @ops[1] ~~ Immediate && @ops[0] ~~ Register {
            my $ev = @ops[1].expr.eval(%env);
            if $ev ~~ NumberExp && $ev.value.abs <= 127 {
                my @matches = @variants.grep({
                        (($_<type> // '') ~~ 'short-imm' | 'reg-imm8')
                        && ($_<width> // 0) == @ops[0].width
                        && (!$_<short_reg> || $_<short_reg>.uc eq @ops[0].name.uc)
                });
                 
                my $best;
                my $width = @ops[0].width;
                if $width == 8 {
                    $best = @matches.grep({ ($_<type> // '') eq 'short-imm' })[0] // @matches[0];
                } elsif $width == 16 {
                    $best = @matches.grep({ ($_<type> // '') eq 'short-imm' })[0] // @matches[0];
                } else { # 32-bit
                    $best = @matches.grep({ ($_<type> // '') eq 'reg-imm8' })[0] // @matches[0];
                }
                return InstructionNode.new(mnemonic => $m, operands => @ops, info => $best) if $best;
            }
        }
        return Nil;
    }

    method !select-variant($mnemonic, @variants, @ops) {
        return {} if @variants.elems == 0;

        # Pseudo-instructions match by mnemonic only
        if (@variants[0]<type> // '') eq 'pseudo' {
            return @variants[0];
        }

        for @variants -> $v {
            if self!match-variant($v, @ops) {
                return $v;
            }
        }
        return {};
    }

    method !match-variant($v, @ops) {
        my $type = $v<type> // '';
        my $v_width = $v<width> // 0;
        debug "Checking variant: type=$type width=$v_width ops={@ops.map(*.Str).join(', ')}";

        given $type {
            when 'pseudo' { return True; }
            when 'reg-reg' {
                return False unless @ops.elems == 2;
                return False unless @ops[0] ~~ Register && @ops[1] ~~ Register;
                return (@ops[0].width == @ops[1].width || (@ops[0].width == 16 && @ops[1].width == 32) || (@ops[0].width == 32 && @ops[1].width == 16))
                && !@ops[0].is-segment && !@ops[1].is-segment
                && !@ops[0].is-control && !@ops[1].is-control;
            }
            when 'sreg-reg' {
                return False unless @ops.elems == 2;
                return False unless @ops[0] ~~ Register && @ops[1] ~~ Register;
                return @ops[0].is-segment && @ops[1].width == 16;
            }
            when 'reg-sreg' {
                return False unless @ops.elems == 2;
                return False unless @ops[0] ~~ Register && @ops[1] ~~ Register;
                return @ops[1].is-segment && @ops[0].width == 16;
            }
            when 'reg-mem' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Memory;
                if $v_width != 0 {
                    return False if @ops[0].width != $v_width;
                }
                return True;
            }
            when 'mem-reg' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Memory && @ops[1] ~~ Register;
                if $v_width != 0 {
                    return False if @ops[1].width != $v_width;
                }
                return True;
            }
            when 'mem-imm8' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Memory && @ops[1] ~~ Immediate;
                if @ops[0].size_prefix {
                    return False unless @ops[0].size_prefix eq 'BYTE';
                }
                return $v_width == 8;
            }
            when 'mem-imm16' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Memory && @ops[1] ~~ Immediate;
                if @ops[0].size_prefix {
                    if @ops[0].size_prefix eq 'WORD' { return $v_width == 16; }
                    if @ops[0].size_prefix eq 'DWORD' { return $v_width == 32; }
                    return False;
                }
                # プレフィックスがない場合は、バリアントの幅が現在のモードに一致するか確認
                return $v_width == (self.bit_mode == 16 ?? 16 !! 32);
            }
            when 'reg-imm8' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Immediate;
                return False if $v<short_reg> && @ops[0].name.uc ne $v<short_reg>.uc;
                my $target_width = $v_width || 8;
                return False if @ops[0].width != $target_width;
                
                # Check value if it's a literal
                my $ev = @ops[1].expr.eval({});
                if $ev ~~ NumberExp {
                    if $target_width == 8 {
                        return False if $ev.value < -128 || $ev.value > 255;
                    } else {
                        return False if $ev.value < -128 || $ev.value > 127;
                    }
                }
                return True;
            }
            when 'reg-imm16' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Immediate;
                return False if $v<short_reg> && @ops[0].name.uc ne $v<short_reg>.uc;
                if $v_width {
                    return @ops[0].width == $v_width;
                }
                return @ops[0].width == 16 || @ops[0].width == 32;
            }
            when 'reg-imm32' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[0].width == 32 && @ops[1] ~~ Immediate;
            }
            when 'short-imm' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Immediate;
                return False if $v<short_reg> && @ops[0].name.uc ne $v<short_reg>.uc;
                return False if $v_width && @ops[0].width != $v_width;
                return True;
            }
            when 'reg-1' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Immediate;
                return False if $v_width && @ops[0].width != $v_width;
                my $ev = @ops[1].expr.eval({});
                return $ev ~~ NumberExp && $ev.value == 1;
            }
            when 'reg-cl' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Register;
                return False if $v_width && @ops[0].width != $v_width;
                return @ops[1].name eq 'CL';
            }
            when 'short-jump' | 'near-jump' | 'imm8' {
                return @ops.elems == 1 && @ops[0] ~~ Immediate;
            }
            when 'imm8-short' {
                return @ops.elems == 2 && @ops[0] ~~ Immediate && @ops[1] ~~ Register
                && (!$v<short_reg> || @ops[1].name eq $v<short_reg>.uc);
            }
            when 'far-jump' {
                return @ops.elems == 1 && @ops[0] ~~ SegmentedAddress;
            }
            when 'mem' {
                return @ops.elems == 1 && @ops[0] ~~ Memory;
            }
            when 'reg-cr' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Register
                && (%REGS_DATA{@ops[1].name.uc}<type> // '') eq 'control';
            }
            when 'cr-reg' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Register
                && (%REGS_DATA{@ops[0].name.uc}<type> // '') eq 'control';
            }
            when 'al-moffs' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[0].name eq 'AL' && @ops[1] ~~ Memory
                && !@ops[1].base && !@ops[1].index;
            }
            when 'ax-moffs' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[0].name eq 'AX' && @ops[1] ~~ Memory
                && !@ops[1].base && !@ops[1].index;
            }
            when 'moffs-al' {
                return @ops.elems == 2 && @ops[0] ~~ Memory && @ops[1] ~~ Register && @ops[1].name eq 'AL'
                && !@ops[0].base && !@ops[0].index;
            }
            when 'moffs-ax' {
                return @ops.elems == 2 && @ops[0] ~~ Memory && @ops[1] ~~ Register && @ops[1].name eq 'AX'
                && !@ops[0].base && !@ops[0].index;
            }
            when 'reg-reg-imm8' {
                return @ops.elems == 3 && @ops[0] ~~ Register && @ops[1] ~~ Register && @ops[2] ~~ Immediate;
            }
            when 'reg-reg-imm16' {
                return @ops.elems == 3 && @ops[0] ~~ Register && @ops[1] ~~ Register && @ops[2] ~~ Immediate;
            }
            when 'reg-reg-2' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Register;
            }
            when 'no-op' {
                return @ops.elems == 0;
            }
        }
        return False;
    }

    method operand_list($/) { make $<operand>».made; }
    method operand($/) {
        if $<sel> {
            my $selector_expr = $<sel>.made;
            my $offset_expr = $<off>.made;
            # selector_expr/offset_expr might be Immediate, we need the Expression inside
            my $sel = $selector_expr ~~ Immediate ?? $selector_expr.expr !! $selector_expr;
            my $off = $offset_expr ~~ Immediate ?? $offset_expr.expr !! $offset_expr;
            my $sa = SegmentedAddress.new(selector => $sel, offset => $off);
            if $<size_prefix> {
                $sa.size_prefix = $<size_prefix>.Str.uc;
            }
            make $sa;
        } else {
            my $made = $<single>.made;
            if $<size_prefix> {
                my $prefix = $<size_prefix>.Str.uc;
                if $made ~~ Memory {
                    $made.size_prefix = $prefix;
                    make $made;
                } else {
                    # If it's not memory, it might be an immediate with a size prefix
                    # (though less common in this assembler's style, we handle it)
                    my $expr = $made ~~ Immediate ?? $made.expr !! $made;
                    make Immediate.new(expr => $expr); # We might need to store size in Immediate too if needed
                }
            } else {
                if $made ~~ Expression {
                    make Immediate.new(expr => $made);
                } else {
                    make $made;
                }
            }
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
        } elsif $<addressing> {
            make $<addressing>.made;
        } else {
            my $f;
            if $<hex_lit> {
                $f = HexFactor.new(value => $<hex_lit>.Str);
            } elsif $<num_lit> {
                $f = NumberFactor.new(value => $<num_lit>.Int);
            } elsif $<string_lit> {
                my $s = $<string_lit>.Str;
                if $/.Str.starts-with("'") {
                    if $s.chars == 1 {
                        $f = CharFactor.new(value => $s);
                    } else {
                        $f = StringFactor.new(value => $s);
                    }
                } else {
                    $f = StringFactor.new(value => $s);
                }
            } elsif $<ident> {
                $f = IdentFactor.new(value => $<ident>.Str);
            } elsif $/.Str eq '$' {
                $f = IdentFactor.new(value => '$');
            }

            if $f {
                make ImmExp.new(factor => $f);
            }
        }
    }

    method addressing($/) {
        my $base;
        if $<base> {
            $base = $<base>.made;
        }

        my $index;
        my $scale = 1;
        my $disp = 0;

        for $/.caps -> $cap {
            if $cap.key eq 'index' {
                $index = Register.new(name => $cap.value.Str.uc);
            } elsif $cap.key eq 'scale' {
                $scale = $cap.value.Int;
            } elsif $cap.key eq 'disp' {
                $disp = $cap.value.made;
            }
        }
        
        my $mem = Memory.new(base => $base);
        if $<index> {
            $mem.index = $<index>[0].made;
            $mem.scale = $<scale>[0].Int if $<scale>;
        }
        if $<disp> {
            $mem.disp = $<disp>[0].made;
        } else {
            $mem.disp = NumberExp.new(value => 0);
        }

        make $mem;
    }

    method reg($/) {
        my $name = $/.Str.uc;
        my $reg_info = %REGS_DATA{$name};
        make Register.new(
            name => $name,
            width => $reg_info<width>,
            index => $reg_info<index>,
            type => $reg_info<type> // 'general'
        );
    }
}
