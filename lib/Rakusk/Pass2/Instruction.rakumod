use v6;
use Rakusk::AST;
use Rakusk::Util;

unit role Rakusk::Pass2::Instruction;

method encode-instruction($node, %regs, %env) {
    my %info = $node.info;
    my $mnemonic = $node.mnemonic;
    my $type = %info<type> // '';

    # 1. プレフィックスの取得
    my $bin = self.get-prefixes($node, %info);

    # 2. オコードの生成
    $bin ~= self.get-base-opcode($node, %info);

    # 3. ModR/M, SIB, Displacement の生成
    $bin ~= self.encode-modrm-sib-disp($node, %info, %env);

    # 4. 即値の生成
    $bin ~= self.encode-immediate($node, %info, %env);

    return $bin;
}

method get-prefixes($node, %info) {
    my $bin = Buf.new();
    my @ops = $node.operands;
    
    # アドレスサイズプレフィックス (0x67)
    if self.needs_67h($node) {
        $bin.push(0x67);
    }
    
    # オペランドサイズプレフィックス (0x66)
    if self.needs_66h($node, %info) {
        $bin.push(0x66);
    }
    
    # 0x0F プレフィックス (一部の命令)
    if %info<type> eq 'sreg' && @ops.elems > 0 && @ops[0].name eq 'FS' | 'GS' {
        $bin.push(0x0F);
    }
    
    return $bin;
}

method needs_66h($node, %info) {
    my $mnemonic = $node.mnemonic;
    my @ops = $node.operands;
    my $type = %info<type> // '';

    # コントロールレジスタ操作は常に 0x66 不要
    return False if $type eq 'reg-cr' | 'cr-reg';

    # セグメントレジスタへのMOV (MOV Sreg, reg) は 0x66 不要 (nask互換)
    return False if $type eq 'sreg-reg';

    # セグメントレジスタ単体 (PUSH/POP SREG) は 0x66 不要
    return False if $type eq 'sreg';

    # IN/OUT の特殊ルール
    if $mnemonic ~~ 'IN' | 'OUT' {
        # ポート指定が DX で、データレジスタが 16/32bit の場合に 0x66 が必要
        my $data_reg = ($mnemonic eq 'IN' ?? @ops[0] !! @ops[1]);
        return False unless $data_reg ~~ Register;
        if self.bit_mode == 16 {
            return $data_reg.width == 32;
        } else { # 32-bit mode
            return $data_reg.width == 16;
        }
    }

    # 一般的なルール: bit_mode とレジスタ/メモリの幅が異なる場合に必要
    for @ops -> $op {
        if $op ~~ Register {
            next if $op.is-segment || $op.is-control;
            if self.bit_mode == 16 {
                return True if $op.width == 32;
            } else { # 32
                return True if $op.width == 16;
            }
        }
        if $op ~~ Memory {
            if self.bit_mode == 16 {
                return True if ($op.size_prefix // '') eq 'DWORD';
            } else { # 32
                return True if ($op.size_prefix // '') eq 'WORD';
            }
        }
        if $op ~~ SegmentedAddress {
            my $use_32bit = (self.bit_mode == 32 || ($op.size_prefix // '') eq 'DWORD');
            return True if self.bit_mode == 16 && $use_32bit;
            return True if self.bit_mode == 32 && !$use_32bit;
        }
    }

    # 命令定義(JSON)側での指定がある場合
    if %info<width>.defined {
        if self.bit_mode == 16 {
            return True if %info<width> == 32;
        } else { # 32
            return True if %info<width> == 16;
        }
    }

    return False;
}

method needs_67h($node) {
    for $node.operands -> $op {
        if $op ~~ Memory {
            my $base = $op.base;
            my $index = $op.index;
            my $is_32bit_addr = ($base && $base ~~ Register && $base.width == 32)
            || ($index && $index ~~ Register && $index.width == 32);
            
            return True if self.bit_mode == 16 && $is_32bit_addr;
            return True if self.bit_mode == 32 && !$is_32bit_addr;
        }
    }
    return False;
}

method get-base-opcode($node, %info) {
    my $type = %info<type> // '';
    my $mnemonic = $node.mnemonic;
    
    if $type ~~ 'reg' | 'reg-imm8' | 'reg-imm16' && %info<base_opcode> {
        my $reg_op = $node.operands[0];
        my $opcode = %info<base_opcode>.parse-base(16) + $reg_op.index;
        return Buf.new($opcode);
    }

    if $type eq 'sreg' {
        my $reg = $node.operands[0];
        my $base = %info<opcode>.parse-base(16);
        if $reg.name eq 'FS' | 'GS' {
            my $op = ($reg.name eq 'FS' ?? 0xA0 !! 0xA8);
            $op += 1 if $node.mnemonic eq 'POP';
            return Buf.new($op);
        }
        my $op = $base + ($reg.index * 8);
        return Buf.new($op);
    }
    
    if $type ~~ 'reg-cr' | 'cr-reg' {
        return Buf.new(0x0F, ($type eq 'reg-cr' ?? 0x20 !! 0x22));
    }

    my $op_hex = %info<opcode> // '';
    my $bin = Buf.new();
    while $op_hex.chars >= 2 {
        $bin.push($op_hex.substr(0, 2).parse-base(16));
        $op_hex = $op_hex.substr(2);
    }
    return $bin;
}

method encode-modrm-sib-disp($node, %info, %env) {
    my $type = %info<type> // '';
    my @ops = $node.operands;
    
    given $type {
        when 'reg-reg' | 'reg-reg-2' {
            my $modrm = pack-modrm(mod => 3, reg => @ops[1].index, rm => @ops[0].index);
            return Buf.new($modrm);
        }
        when 'sreg-reg' {
            my $modrm = pack-modrm(mod => 3, reg => @ops[0].index, rm => @ops[1].index);
            return Buf.new($modrm);
        }
        when 'reg-sreg' {
            my $modrm = pack-modrm(mod => 3, reg => @ops[1].index, rm => @ops[0].index);
            return Buf.new($modrm);
        }
        when 'sreg' {
            # オプコードは get-base-opcode で処理済み
            return Buf.new();
        }
        when 'reg' | 'reg-imm8' | 'reg-imm16' {
            return Buf.new() if %info<base_opcode>;
            my $reg_field = %info<extension> // @ops[0].index;
            my $rm_field = @ops[0].index;
            my $modrm = pack-modrm(mod => 3, reg => $reg_field // 0, rm => $rm_field // 0);
            return Buf.new($modrm);
        }
        when 'reg-mem' | 'mem-reg' {
            my $reg_op = @ops.grep(Register)[0];
            my $mem_op = @ops.grep(Memory)[0];
            my ($mod, $rm, $disp_bytes, $sib, $needs_67) = self.encode_mem_op($mem_op, %env);
            my $modrm = pack-modrm(mod => $mod, reg => $reg_op.index, rm => $rm);
            my $bin = Buf.new($modrm);
            $bin ~= $sib if $sib;
            $bin ~= $disp_bytes if $disp_bytes;
            return $bin;
        }
        when 'mem-imm8' | 'mem-imm16' | 'mem' | 'mem-far' {
            my $mem_op = @ops.grep(Memory)[0];
            my ($mod, $rm, $disp_bytes, $sib, $needs_67) = self.encode_mem_op($mem_op, %env);
            my $reg_field = %info<extension> // 0;
            # debug "DEBUG: mod=$mod reg=$reg_field rm=$rm" if %*ENV<RAKUSK_DEBUG>;
            my $modrm = pack-modrm(mod => $mod // 0, reg => $reg_field, rm => $rm // 0);
            my $bin = Buf.new($modrm);
            $bin ~= $sib if $sib;
            $bin ~= $disp_bytes if $disp_bytes;
            return $bin;
        }
        when 'reg-cr' | 'cr-reg' {
            my $reg_op = @ops.grep({ $_ ~~ Register && !$_.is-control })[0];
            my $cr_op = @ops.grep({ $_ ~~ Register && $_.is-control })[0];
            my $modrm = pack-modrm(mod => 3, reg => $cr_op.index, rm => $reg_op.index);
            return Buf.new($modrm);
        }
        when 'reg-reg-imm8' | 'reg-reg-imm16' {
            my $modrm = pack-modrm(mod => 3, reg => @ops[0].index, rm => @ops[1].index);
            return Buf.new($modrm);
        }
        when 'al-moffs' | 'ax-moffs' | 'moffs-al' | 'moffs-ax' {
            # moffs 形式は ModR/M バイトを持たない
            return Buf.new();
        }
    }
    return Buf.new();
}

method encode-immediate($node, %info, %env) {
    my $type = %info<type> // '';
    my @ops = $node.operands;
    my $bin = Buf.new();

    given $type {
        when 'reg-imm8' | 'mem-imm8' | 'imm8' | 'imm8-short' | 'reg-reg-imm8' {
            my $imm_op = @ops.grep(Immediate)[0];
            if $imm_op {
                my $val = self.eval-to-int($imm_op, %env);
                $bin ~= pack-le($val, 8);
            }
        }
        when 'reg-imm16' | 'mem-imm16' | 'reg-reg-imm16' | 'short-imm' {
            my $imm_op = @ops.grep(Immediate)[0];
            my $val = self.eval-to-int($imm_op, %env);
            my $width = %info<width>;
            if !$width {
                if @ops.grep({ $_ ~~ Register && $_.width == 32 }) {
                    $width = 32;
                } elsif @ops.grep({ $_ ~~ Register && $_.width == 16 }) {
                    $width = 16;
                } elsif @ops.grep({ $_ ~~ Memory && ($_.size_prefix // '') eq 'DWORD' }) {
                    $width = 32;
                } elsif @ops.grep({ $_ ~~ Memory && ($_.size_prefix // '') eq 'WORD' }) {
                    $width = 16;
                } else {
                    $width = (self.bit_mode == 16 ?? 16 !! 32);
                }
            }
            $bin ~= pack-le($val, $width);
        }
        when 'short-jump' {
            my $target = self.eval-to-int(@ops[0], %env);
            my $offset = $target - (%env<PC> + 2);
            $bin ~= pack-le($offset, 8);
        }
        when 'near-jump' {
            my $target_op = @ops[0];
            my $width = (self.bit_mode == 16 ?? 16 !! 32);
            my $inst_size = (self.bit_mode == 16 ?? 3 !! 5);
            
            # WCOFF での EXTERN シンボルへの CALL/JMP 処理
            if $target_op ~~ Immediate && $target_op.expr.factor ~~ IdentFactor {
                my $name = $target_op.expr.factor.value;
                if self.output_format.uc eq 'WCOFF' && self.extern_symbols.grep({ $_ eq $name }) {
                    # リロケーションの追加
                    if %env<relocations>.defined {
                        say "DEBUG: Pushing relocation for ", $name if %*ENV<RAKUSK_DEBUG>;
                        # sym_idx は .file (2) + sections (3*2=6) = 8
                        # その後 EXTERN, GLOBAL の順に並ぶ
                        my $sym_idx = 8;
                        # EXTERN, GLOBAL の順を正確に守る
                        my $found = False;
                        # .file(2) + sections(3*2) = 8
                        # syms に追加される順序を再現する必要がある:
                        # 1. extern_symbols
                        # 2. global_symbols
                        
                        # 重複を排除した順序
                        my @all_externs = self.extern_symbols.unique;
                        my @all_globals = self.global_symbols.unique;

                        for @all_externs -> $e {
                            if $e eq $name { $found = True; last; }
                            $sym_idx++;
                        }
                        unless $found {
                            for @all_globals -> $g {
                                if $g eq $name { $found = True; last; }
                                $sym_idx++;
                            }
                        }
                        %env<relocations>.push({
                            offset => %env<PC> + 1,
                            sym_idx => $sym_idx,
                            type => 20 # REL_I386_REL32
                        });
                    }
                    # EXTERN の場合は 0 をベースにする (gosk / nask に合わせる)
                    # ただし nask (WCOFF) では、CALL EXTERN は e8 fd ff ff ff (-3) などの
                    # 相対オフセットが書き込まれることがある（再配置対象のベース値）
                    # 今回の expected では e8 00 00 00 00 (0) になっている可能性も考慮
                    $bin ~= pack-le(0, $width);
                    return $bin;
                }
            }
            
            my $target = self.eval-to-int($target_op, %env);
            my $offset = $target - (%env<PC> + $inst_size);
            $bin ~= pack-le($offset, $width);
        }
        when 'far-jump' {
            my $op = @ops[0];
            my $selector = self.eval-to-int($op.selector, %env);
            my $offset = self.eval-to-int($op.offset, %env);
            my $use_32bit = (self.bit_mode == 32 || ($op.size_prefix // '') eq 'DWORD');
            
            $bin ~= pack-le($offset, $use_32bit ?? 32 !! 16);
            $bin ~= pack-le($selector, 16);
        }
        when 'al-moffs' | 'ax-moffs' | 'moffs-al' | 'moffs-ax' {
            my $mem_op = @ops.grep(Memory)[0];
            my $val = self.eval-to-int($mem_op.disp, %env);
            # moffs のアドレス幅は 16-bit モードなら 16-bit、32-bit モードなら 32-bit
            $bin ~= pack-le($val, self.bit_mode == 16 ?? 16 !! 32);
        }
    }
    return $bin;
}

method encode_mem_op($mem, %env) {
    return (0, 0, Buf.new(), Buf.new(), False) unless $mem ~~ Memory;
    my $base_reg = $mem.base ~~ Register ?? $mem.base !! Nil;
    my $index_reg = $mem.index ~~ Register ?? $mem.index !! Nil;
    
    my $is_32bit_addr = ($base_reg && $base_reg.width == 32) || ($index_reg && $index_reg.width == 32);
    
    if $is_32bit_addr {
        return self.encode_mem_op_32($mem, %env);
    } else {
        return self.encode_mem_op_16($mem, %env);
    }
}

method encode_mem_op_16($mem, %env) {
    my $base = $mem.base ~~ Register ?? $mem.base.Str.uc !! ($mem.base // '');
    my $index = $mem.index ~~ Register ?? $mem.index.Str.uc !! ($mem.index // '');
    my $dv = self.eval-to-int($mem.disp, %env);
    my $needs_67 = self.bit_mode == 32;

    my $rm;
    if $base eq 'BX' && $index eq 'SI' { $rm = 0; }
    elsif $base eq 'BX' && $index eq 'DI' { $rm = 1; }
    elsif $base eq 'BP' && $index eq 'SI' { $rm = 2; }
    elsif $base eq 'BP' && $index eq 'DI' { $rm = 3; }
    elsif $base eq 'SI' && $index eq '' { $rm = 4; }
    elsif $base eq 'DI' && $index eq '' { $rm = 5; }
    elsif $base eq 'BP' && $index eq '' { $rm = 6; }
    elsif $base eq 'BX' && $index eq '' { $rm = 7; }
    elsif $base eq '' && $index eq '' { $rm = 6; }
    else { return (0, 0, Buf.new(), Buf.new(), False); }

    my $mod;
    my $disp_bytes = Buf.new();
    if $base eq '' && $index eq '' {
        $mod = 0; $rm = 6;
        $disp_bytes.push($dv % 256, ($dv +> 8) % 256);
    } elsif $dv == 0 && $rm != 6 {
        $mod = 0;
    } elsif $dv.abs <= 127 {
        $mod = 1;
        $disp_bytes.push($dv % 256);
    } else {
        $mod = 2;
        $disp_bytes.push($dv % 256, ($dv +> 8) % 256);
    }
    return ($mod, $rm, $disp_bytes, Buf.new(), $needs_67);
}

method encode_mem_op_32($mem, %env) {
    my $base_reg = $mem.base ~~ Register ?? $mem.base !! Nil;
    my $index_reg = $mem.index ~~ Register ?? $mem.index !! Nil;
    my $dv = self.eval-to-int($mem.disp, %env);
    my $needs_67 = self.bit_mode == 16;
    
    my $mod;
    my $rm;
    my $sib = Buf.new();
    my $disp_bytes = Buf.new();

    if !$base_reg && !$index_reg {
        $mod = 0; $rm = 5;
        $disp_bytes.push($dv % 256, ($dv +> 8) % 256, ($dv +> 16) % 256, ($dv +> 24) % 256);
    } elsif $base_reg && !$index_reg {
        $rm = $base_reg.index;
        if $rm == 4 { # ESP base needs SIB
            $sib.push(0x24); # SS=0, Index=4 (none), Base=4 (ESP)
        }
        if $dv == 0 && $rm != 5 {
            $mod = 0;
        } elsif $dv.abs <= 127 {
            $mod = 1;
            $disp_bytes.push($dv % 256);
        } else {
            $mod = 2;
            $disp_bytes.push($dv % 256, ($dv +> 8) % 256, ($dv +> 16) % 256, ($dv +> 24) % 256);
        }
    } else {
        $rm = 4;
        my $ss = 0; # scale 1
        my $index_idx = $index_reg.index;
        my $base_idx = $base_reg ?? $base_reg.index !! 5; # 5 means no base if mod=0
        $sib.push(($ss +< 6) +| ($index_idx +< 3) +| $base_idx);
        
        if !$base_reg {
            $mod = 0;
            $disp_bytes.push($dv % 256, ($dv +> 8) % 256, ($dv +> 16) % 256, ($dv +> 24) % 256);
        } elsif $dv == 0 && $base_idx != 5 {
            $mod = 0;
        } elsif $dv.abs <= 127 {
            $mod = 1;
            $disp_bytes.push($dv % 256);
        } else {
            $mod = 2;
            $disp_bytes.push($dv % 256, ($dv +> 8) % 256, ($dv +> 16) % 256, ($dv +> 24) % 256);
        }
    }
    
    return ($mod, $rm, $disp_bytes, $sib, $needs_67);
}
