use v6;
unit module Rakusk::Actions;
use Rakusk::AST;
use Rakusk::Util;
use Rakusk::Log;

# Grammar側で定義された %MNEMONIC_MAP を参照するための準備
# 物理分離後は、共通のデータソースから構築するか、引数で渡す必要がある。
# ここでは一旦、Rakusk::Util から構築するロジックを保持する。
my %MNEMONIC_MAP;
for %Rakusk::Util::INST_DATA.kv -> $key, $val {
    my $m = $val<mnemonic> // $key;
    %MNEMONIC_MAP{$m.uc} //= [];
    %MNEMONIC_MAP{$m.uc}.push($val);
}

# バリアントの優先順位付け
for %MNEMONIC_MAP.kv -> $m, $variants {
    %MNEMONIC_MAP{$m} = [ $variants.sort({
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

# Evaluator ロールは Rakusk::Util で定義されている
use Rakusk::Util;

class AssemblerActions is export does Rakusk::Util::Evaluator {
    has Int $.bit_mode is rw = 16;
    has %!symbols;
    has %!externs;
    has Str $!current_global_label = "";

    method TOP($/) {
        make $<statement>».made.grep(*.defined);
    }

    method statement($/) {
        my $label = $<label_stmt> ?? $<label_stmt>.made !! Nil;
        my $inst = $<instruction_or_directive> ?? $<instruction_or_directive>.made !! Nil;

        if $label && $inst {
            make [$label, $inst];
        } elsif $label {
            make $label;
        } elsif $inst {
            make $inst;
        } else {
            # Comment or empty (should not happen if grammar is correct)
            make Nil;
        }
    }

    method instruction_or_directive($/) {
        make $/.values[0].made;
    }

    method label_stmt($/) {
        my $name = $<label><ident>.Str;
        if $name.starts-with('.') {
            $name = $!current_global_label ~ $name;
        } else {
            $!current_global_label = $name;
        }
        make LabelStmt.new(label => $name);
    }

    method declare_stmt($/) {
        my $name = ($<ident> // $<ident_not_reserved>).Str;
        if $name.starts-with('.') {
            $name = $!current_global_label ~ $name;
        }
        my $val_expr = $<exp>.made;
        my $node = DeclareStmt.new(name => $name, value => $val_expr);
        my $val = self.eval-to-any($val_expr, { symbols => %!symbols });
        %!symbols{$name} = $val if $val ~~ Int;
        make $node;
    }

    method export_sym_stmt($/) {
        make ExportSymStmt.new(symbols => $<ident>».Str);
    }

    method extern_sym_stmt($/) {
        my @names = $<ident>».Str;
        %!externs{$_} = True for @names;
        make ExternSymStmt.new(symbols => @names);
    }

    method config_stmt($/) {
        my $type = $<config_type>.Str.uc;
        my $node = ConfigStmt.new(type => $type, value => $<exp>.made);
        if $type eq 'BITS' {
            $!bit_mode = self.eval-to-int($node.value, {});
        }
        make $node;
    }

    method org_stmt($/) {
        make ConfigStmt.new(type => 'ORG', value => $<exp>.made);
    }

    method db_stmt($/) {
        make PseudoNode.new(mnemonic => $/.Str.trim.split(/\s+/)[0].uc, operands => $<operand_list>.made);
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
        if $m eq 'JMP' | 'CALL' && @ops.elems == 1 && @ops[0] ~~ Immediate {
            my $ev = @ops[0].expr.eval({});
            if $ev ~~ NumberExp {
                my $near = @variants.grep({ ($_<type> // '') eq 'near-jump' })[0];
                return InstructionNode.new(mnemonic => $m, operands => @ops, info => $near) if $near;
            }
        }

        if $m ~~ /^(ADD|SUB|CMP|AND|OR|XOR|ADC|SBB)$/ && @ops.elems == 2 && @ops[1] ~~ Immediate && (@ops[0] ~~ Register | Memory) {
            if @ops[1].expr.is-imm8(%env) {
                my $op_width = 0;
                if @ops[0] ~~ Register {
                    $op_width = @ops[0].width;
                } elsif @ops[0] ~~ Memory {
                    if @ops[0].size_prefix {
                        $op_width = 8 if @ops[0].size_prefix eq 'BYTE';
                        $op_width = 16 if @ops[0].size_prefix eq 'WORD';
                        $op_width = 32 if @ops[0].size_prefix eq 'DWORD';
                    } else {
                        $op_width = (self.bit_mode == 16 ?? 16 !! 32);
                    }
                }

                if $op_width != 8 {
                    my $is_ax_16 = @ops[0] ~~ Register && @ops[0].name eq 'AX' && $op_width == 16;
                    my $is_eax_32 = @ops[0] ~~ Register && @ops[0].name eq 'EAX' && $op_width == 32;

                    my $best = @variants.grep({ ($_<opcode> // '') eq '83' && ($_<width> // 0) == $op_width })[0];
                    if $best && !$is_ax_16 {
                        my %info = %$best;
                        %info<width> //= $op_width;
                        my $ext = Nil;
                        if $m eq 'ADD' { $ext = 0 }
                        elsif $m eq 'OR' { $ext = 1 }
                        elsif $m eq 'ADC' { $ext = 2 }
                        elsif $m eq 'SBB' { $ext = 3 }
                        elsif $m eq 'AND' { $ext = 4 }
                        elsif $m eq 'SUB' { $ext = 5 }
                        elsif $m eq 'XOR' { $ext = 6 }
                        elsif $m eq 'CMP' { $ext = 7 }
                        %info<extension> //= $ext;
                        if @ops[0] ~~ Register {
                            %info<type> = 'reg-imm8';
                        } else {
                            %info<type> = 'mem-imm8';
                        }
                        return InstructionNode.new(mnemonic => $m, operands => @ops, info => %info) if %info<extension>.defined;
                    }
                }
            }
        }
        return Nil;
    }

    method !select-variant($mnemonic, @variants, @ops) {
        return {} if @variants.elems == 0;
        if (@variants[0]<type> // '') eq 'pseudo' {
            return @variants[0];
        }
        for @variants -> $v {
            if ($v<width> // 0) == $.bit_mode {
                if self!match-variant($v, @ops) {
                    return $v;
                }
            }
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
                return False unless @ops[0] ~~ Register && (@ops[1] ~~ Register || @ops[1] ~~ Memory);
                return @ops[0].is-segment && (@ops[1] !~~ Register || @ops[1].width == 16 || @ops[1].width == 32);
            }
            when 'reg-sreg' {
                return False unless @ops.elems == 2;
                return False unless (@ops[0] ~~ Register || @ops[0] ~~ Memory) && @ops[1] ~~ Register;
                return @ops[1].is-segment && (@ops[0] !~~ Register || @ops[0].width == 16 || @ops[0].width == 32);
            }
            when 'reg-mem' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Memory;
                return False if @ops[0].is-segment || @ops[0].is-control;
                if $v_width != 0 {
                    return False if @ops[0].width != $v_width;
                }
                return True;
            }
            when 'mem-reg' {
                return False unless @ops.elems == 2 && @ops[0] ~~ Memory && @ops[1] ~~ Register;
                return False if @ops[1].is-segment || @ops[1].is-control;
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
                return $v_width == (self.bit_mode == 16 ?? 16 !! 32);
            }
            when 'reg-imm8' {
                return False unless @ops.elems == 2 && (@ops[0] ~~ Register || @ops[0] ~~ Memory) && @ops[1] ~~ Immediate;

                my $target_width = $v_width || 8;
                my $op_width = 0;
                if @ops[0] ~~ Register {
                    $op_width = @ops[0].width;
                } else { # Memory
                    $op_width = $target_width;
                    if @ops[0].size_prefix {
                        given @ops[0].size_prefix {
                            when 'BYTE' { $op_width = 8 }
                            when 'WORD' { $op_width = 16 }
                            when 'DWORD' { $op_width = 32 }
                        }
                    }
                }
                return False if $op_width != $target_width;

                if @ops[0] ~~ Register {
                    return False if $v<short_reg> && @ops[0].name.uc ne $v<short_reg>.uc;
                }

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
                return False unless @ops.elems == 2 && (@ops[0] ~~ Register || @ops[0] ~~ Memory) && @ops[1] ~~ Immediate;
                
                if @ops[0] ~~ Register {
                    return False if $v<short_reg> && @ops[0].name.uc ne $v<short_reg>.uc;
                    if $v_width {
                        return @ops[0].width == $v_width;
                    }
                    return @ops[0].width == 16 || @ops[0].width == 32;
                } else { # Memory
                    my $op_width = 0;
                    if @ops[0].size_prefix {
                        given @ops[0].size_prefix {
                            when 'WORD' { $op_width = 16 }
                            when 'DWORD' { $op_width = 32 }
                            default { return False; }
                        }
                    } else {
                        $op_width = self.bit_mode;
                    }

                    if $v_width {
                        return $op_width == $v_width;
                    }
                    return True;
                }
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
                if $type eq 'short-jump' {
                    my $op = @ops[0];
                    if $op ~~ Immediate && $op.expr.factor ~~ IdentFactor {
                        my $name = $op.expr.factor.value;
                        return False if %!externs{$name};
                    }
                }
                return @ops.elems == 1 && @ops[0] ~~ Immediate;
            }
            when 'imm8-short' {
                return @ops.elems == 2 && @ops[0] ~~ Immediate && @ops[1] ~~ Register
                && (!$v<short_reg> || @ops[1].name eq $v<short_reg>.uc);
            }
            when 'far-jump' {
                return @ops.elems == 1 && @ops[0] ~~ SegmentedAddress;
            }
            when 'mem-far' {
                return @ops.elems == 1 && @ops[0] ~~ Memory && (@ops[0].size_prefix // '') eq 'FAR';
            }
            when 'mem' {
                return @ops.elems == 1 && @ops[0] ~~ Memory;
            }
            when 'reg-cr' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Register
                && (%Rakusk::Util::REGS_DATA{@ops[1].name.uc}<type> // '') eq 'control';
            }
            when 'cr-reg' {
                return @ops.elems == 2 && @ops[0] ~~ Register && @ops[1] ~~ Register
                && (%Rakusk::Util::REGS_DATA{@ops[0].name.uc}<type> // '') eq 'control';
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
            when 'reg' {
                return False unless @ops.elems == 1 && @ops[0] ~~ Register;
                return False if @ops[0].is-segment || @ops[0].is-control;
                return False if $v_width && @ops[0].width != $v_width;
                return True;
            }
            when 'in-out-reg' {
                return False unless @ops.elems == 2;
                my ($r1, $r2);
                if $v<mnemonic> eq 'IN' {
                    ($r1, $r2) = @ops;
                } else { # OUT
                    ($r2, $r1) = @ops;
                }
                return False unless $r1 ~~ Register && $r2 ~~ Register;
                return False if $v_width && $r1.width != $v_width;
                return $r2.name eq 'DX' && ($r1.name eq 'AL' | 'AX' | 'EAX');
            }
            when 'sreg' {
                return @ops.elems == 1 && @ops[0] ~~ Register && @ops[0].is-segment;
            }
            return False;
        }
    }

    method operand_list($/) { make $<operand>».made; }
    method operand($/) {
        if $<sel> {
            my $selector_expr = $<sel>.made;
            my $offset_expr = $<off>.made;
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
                    my $expr = $made ~~ Immediate ?? $made.expr !! $made;
                    make Immediate.new(expr => $expr);
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
            } elsif ($<ident> // $<ident_not_reserved>) -> $id {
                my $name = $id.Str;
                if $name.starts-with('.') {
                    $name = $!current_global_label ~ $name;
                }
                $f = IdentFactor.new(value => $name);
            } elsif $/.Str eq '$' {
                $f = IdentFactor.new(value => '$');
            }

            if $f {
                make ImmExp.new(factor => $f);
            }
        }
    }

    method addressing($/) {
        my $mem = Memory.new();

        if $<seg_override> {
            my $prefix_str = $<seg_override>.Str;
            my $reg_name = $prefix_str.substr(0, $prefix_str.chars - 1).uc;
            my $reg_info = %Rakusk::Util::REGS_DATA{$reg_name};
            $mem.seg_override = Register.new(
                name => $reg_name,
                width => $reg_info<width>,
                index => $reg_info<index>,
                type => $reg_info<type> // 'segment'
            );
        }

        if $<base> {
            $mem.base = $<base>.made;
        }

        my @indices = $<index>».made;
        my @disps = $<disp>».made;

        if @indices.elems > 0 {
            $mem.index = @indices[0];
            $mem.scale = $<scale>[0].Int if $<scale> && $<scale>[0];
        }

        if @disps.elems > 0 {
             if $mem.base {
                $mem.disp = @disps[0];
             } else {
                if !$<base> && $<disp> {
                    $mem.disp = $<disp>[0].made;
                }
             }
        }
        $mem.disp //= NumberExp.new(value => 0);
        make $mem;
    }

    method reg($/) {
        my $name = $/.Str.uc;
        my $reg_info = %Rakusk::Util::REGS_DATA{$name};
        make Register.new(
            name => $name,
            width => $reg_info<width>,
            index => $reg_info<index>,
            type => $reg_info<type> // 'general'
        );
    }
}