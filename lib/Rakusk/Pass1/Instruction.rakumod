use v6;
use Rakusk::AST;

unit role Rakusk::Pass1::Instruction;

method process-instruction($node, %regs, %env) {
    my $mnemonic = $node.mnemonic;
    
    # ジャンプ命令判定
    if $mnemonic ~~ /^ J | ^ CALL / {
        self.process-JMP($node, %regs, %env);
        return;
    }

    # ハンドラ振り分け
    given $mnemonic {
        when 'MOV' { self.process-MOV($node, %regs, %env); }
        when 'RET' { self.process-RET($node, %regs, %env); }
        when 'INT' { self.process-INT($node, %regs, %env); }
        when 'IN'  { self.process-IN($node, %regs, %env); }
        when 'OUT' { self.process-OUT($node, %regs, %env); }
        when 'LGDT' { self.process-LGDT($node, %regs, %env); }
        # 算術・論理演算命令
        when 'ADD' | 'ADC' | 'SUB' | 'SBB' | 'CMP' | 'INC' | 'DEC' | 'NEG' | 'MUL' | 'IMUL' | 'DIV' | 'IDIV' |
                'AND' | 'OR' | 'XOR' | 'NOT' | 'SHR' | 'SHL' | 'SAR' {
            self.process-arith-logic($node, %regs, %env);
        }
        # PUSH/POP
        when 'PUSH' | 'POP' {
            self.process-push-pop($node, %regs, %env);
        }
        default {
            # パラメータなし命令またはデフォルト処理
            self.process-generic-inst($node, %regs, %env);
        }
    }
}

method process-MOV($node, %regs, %env) {
    my $size = self.size-of-instruction($node, %regs, %env);
    self.pc += $size;
}

method process-INT($node, %regs, %env) {
    my $size = 2; # INT imm8
    if $node.operands.elems > 0 {
        my $val = self.eval-to-any($node.operands[0], %env);
        if $val == 3 {
            $size = 1; # INT 3 (CC)
        }
    }
    self.pc += $size;
}

method process-IN($node, %regs, %env) {
    my $size = self.size-of-instruction($node, %regs, %env);
    self.pc += $size;
}

method process-OUT($node, %regs, %env) {
    my $size = self.size-of-instruction($node, %regs, %env);
    self.pc += $size;
}

method process-LGDT($node, %regs, %env) {
    # LGDT m16:32 (0F 01 /2)
    my $size = 5; 
    self.pc += $size;
}

method process-arith-logic($node, %regs, %env) {
    my $size = self.size-of-instruction($node, %regs, %env);
    self.pc += $size;
}

method process-push-pop($node, %regs, %env) {
    my $size = self.size-of-instruction($node, %regs, %env);
    self.pc += $size;
}

method process-generic-inst($node, %regs, %env) {
    my $mnemonic = $node.mnemonic;
    my $size = 1;

    given $mnemonic {
        when 'IRETQ' | 'SYSENTER' | 'SYSEXIT' | 'SYSCALL' | 'SYSRET' | 'UD2' {
            $size = 2;
        }
        when /^F/ {
            $size = 2;
        }
        default {
            my $info_size = self.size-of-instruction($node, %regs, %env);
            $size = $info_size if $info_size > 0;
        }
    }
    self.pc += $size;
}

method process-RET($node, %regs, %env) {
    my $size = 1;
    if $node.operands.elems > 0 {
        $size = 3;
    }
    self.pc += $size;
}

method process-JMP($node, %regs, %env) {
    my $mnemonic = $node.mnemonic;
    my @operands = $node.operands;
    my %info = $node.info;

    if %info<type> eq 'near-jump' {
        self.pc += (self.bit_mode == 16 ?? 3 !! 5);
        return;
    }

    my $size = 0;
    if @operands.elems > 0 {
        my $op = @operands[0];
        if $op ~~ SegmentedAddress {
            # JMP selector:offset
            my $use_32bit = (self.bit_mode == 32 || ($op.size_prefix // '') eq 'DWORD');
            if $use_32bit {
                $size = 7; # ptr16:32
                if self.bit_mode == 16 {
                    $size += 1; # 66h prefix
                }
            } else {
                $size = 5; # ptr16:16
            }
        } else {
            $size = self.estimate-jump-size($mnemonic, self.bit_mode);
        }
    } else {
        $size = self.estimate-jump-size($mnemonic, self.bit_mode);
    }
    
    self.pc += $size;
}

method estimate-jump-size($mnemonic, $bit_mode) {
    if $bit_mode == 16 {
        if $mnemonic eq 'CALL' {
            return 3;
        }
        return 2;
    }
    
    if $mnemonic eq 'JMP' || $mnemonic eq 'CALL' {
        return 5;
    }
    return 6;
}

method calc-inst-mem-size($mem, %env) {
    return 1 unless $mem ~~ Memory; # Fallback to ModRM only
    
    my $base_reg = $mem.base ~~ Register ?? $mem.base !! Nil;
    my $index_reg = $mem.index ~~ Register ?? $mem.index !! Nil;
    my $dv = self.eval-to-int($mem.disp, %env);
    
    my $is_32bit = ($base_reg && $base_reg.width == 32) || ($index_reg && $index_reg.width == 32);
    my $size = 1; # ModRM
    
    if self.bit_mode == 16 && $is_32bit {
        $size += 1; # 67h
    } elsif self.bit_mode == 32 && !$is_32bit {
        $size += 1; # 67h
    }

    if $is_32bit {
        # 32-bit addressing size calculation
        if !$base_reg && !$index_reg {
            $size += 4; # [disp32]
        } else {
            if $index_reg || ($base_reg && $base_reg.index == 4) {
                $size += 1; # SIB
            }
            if $dv == 0 {
                if $base_reg && $base_reg.index == 5 { $size += 1; } # [EBP] needs disp8
            } elsif $dv.abs <= 127 {
                $size += 1; # disp8
            } else {
                $size += 4; # disp32
            }
        }
    } else {
        # 16-bit addressing size calculation
        if !$base_reg && !$index_reg {
            $size += 2; # [disp16]
        } else {
            if $dv == 0 {
                # [BP] always needs disp8 in 16-bit
                my $base_name = $base_reg ?? $base_reg.name.uc !! '';
                if $base_name eq 'BP' && !$index_reg { $size += 1; }
            } elsif $dv.abs <= 127 {
                $size += 1; # disp8
            } else {
                $size += 2; # disp16
            }
        }
    }
    return $size;
}

method size-of-instruction($node, %regs, %env) {
    my %info = $node.info;
    return 0 unless %info;
    my $type = %info<type> // '';

    given $type {
        when 'no-op' { return 1; }
        when 'reg-imm8' {
            my $reg = $node.operands[0];
            my $size = %info<base_opcode> ?? 2 !! 3;
            if self.bit_mode == 16 && $reg.width == 32 {
                $size += 1; # 66h prefix
            }
            return $size;
        }
        when 'short-imm' {
            my $size = 1; # Opcode
            if (%info<width> // 8) == 8 {
                $size += 1;
            } elsif %info<width> == 16 {
                $size += 2;
            } else { # 32
                $size += 4;
            }
            if self.bit_mode == 16 && (%info<width> // 0) == 32 {
                $size += 1; # 66h
            }
            return $size;
        }
        when 'reg-imm16' {
            my $reg = $node.operands[0];
            my $size = %info<base_opcode> ?? 1 !! 2; # Opcode or Opcode+ModRM
            if $reg.width == 16 {
                $size += 2;
            } else {
                $size += 4;
            }
            if self.bit_mode == 16 && $reg.width == 32 {
                $size += 1; # 66h prefix
            }
            return $size;
        }
        when 'imm8' { return 2; }
        when 'imm16' { return 3; }
        when 'imm32' { return 5; }
        when 'short-jump' { return 2; }
        when 'reg-reg' {
            my $size = 2;
            my $dst = $node.operands[0];
            if self.bit_mode == 16 && $dst.width == 32 {
                $size += 1; # 66h
            }
            return $size;
        }
        when 'sreg-reg' | 'reg-sreg' { return 2; }
        when 'reg-mem' | 'mem-reg' {
            my $reg = $node.operands.grep(Register)[0];
            my $mem = $node.operands.grep(Memory)[0];
            my $size = self.calc-inst-mem-size($mem, %env);
            $size += 1; # Opcode
            if self.bit_mode == 16 && $reg.width == 32 {
                $size += 1; # 66h
            }
            return $size;
        }
        when 'mem-imm8' | 'mem-imm16' {
            my $mem = $node.operands.grep(Memory)[0];
            my $size = self.calc-inst-mem-size($mem, %env);
            $size += 1; # Opcode
            my $imm_size = ($type eq 'mem-imm8' ?? 1 !! 2);
            if self.bit_mode == 16 && (($mem.size_prefix // '') eq 'DWORD' || $type eq 'mem-imm32') {
                 $size += 1; # 66h prefix
                 $imm_size = 4;
            }
            $size += $imm_size;
            return $size;
        }
        when /moffs/ {
            return (self.bit_mode == 16 ?? 3 !! 5);
        }
        when 'mem' {
            my $mem = $node.operands[0];
            my $size = self.calc-inst-mem-size($mem, %env);
            $size += (%info<opcode> // '').chars / 2;
            # calc-inst-mem-size handles 67h and ModRM and Displacement
            return $size;
        }
        when 'reg-cr' | 'cr-reg' {
            return 3; # 0F 20/22 /r
        }
        when 'reg-reg-imm8' | 'reg-reg-imm16' {
            my $reg = $node.operands[0];
            my $size = 2; # Opcode + ModRM
            if $type eq 'reg-reg-imm8' {
                $size += 1;
            } else {
                $size += ($reg.width == 16 ?? 2 !! 4);
            }
            if self.bit_mode == 16 && $reg.width == 32 {
                $size += 1; # 66h
            }
            return $size;
        }
        when 'reg-reg-2' {
            my $reg = $node.operands[0];
            my $size = (%info<opcode> // '').chars / 2;
            $size += 1; # ModRM
            if self.bit_mode == 16 && $reg.width == 32 {
                $size += 1; # 66h
            }
            return $size;
        }
        when 'imm8-short' {
            return 2;
        }
    }
    return 0;
}