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

    my $size = 0;
    if @operands.elems > 0 {
        my $op = @operands[0];
        if $op ~~ SegmentedAddress {
            # JMP selector:offset
            # 16-bit mode: EA + ptr16:16/32 -> 5 or 7 bytes
            # In 16-bit mode, it's usually EA + ptr16:16 (5 bytes) 
            # but if it's a 32-bit offset it can be 7 bytes.
            # gosk says: estimatedSize = 8 (66h + EA + ptr16:32) in 16-bit mode
            # or 7 (EA + ptr16:32) in 32-bit mode.
            if self.bit_mode == 16 {
                $size = 5; # Assume 16-bit offset for now: EA (1) + OFF (2) + SEG (2) = 5
                # If it's harib00i: JMP DWORD 2*8:0x0000001b
                # The DWORD prefix should tell us it's 32-bit offset.
                # However, our SegmentedAddress doesn't have size info yet.
            } else {
                $size = 7; # EA (1) + OFF (4) + SEG (2) = 7
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

method size-of-instruction($node, %regs, %env) {
    my %info = $node.info;
    return 0 unless %info;

    given %info<type> {
        when 'no-op' { return 1; }
        when 'reg-imm8' {
            return %info<base_opcode> ?? 2 !! 3;
        }
        when 'short-imm' {
            return (%info<width> // 8) == 8 ?? 2 !! 3;
        }
        when 'reg-imm16' { return 3; }
        when 'imm8' { return 2; }
        when 'imm16' { return 3; }
        when 'imm32' { return 5; }
        when 'short-jump' { return 2; }
        when 'reg-reg' { return 2; }
        when 'sreg-reg' | 'reg-sreg' { return 2; }
        when 'reg-mem' | 'mem-reg' {
            my $size = 2;
            my $mem = $node.operands.grep(Memory)[0];
            if $mem && $mem.disp {
                my $dv = self.eval-to-int($mem.disp, %env);
                if $dv != 0 {
                    $size += ($dv.abs <= 127 ?? 1 !! 2);
                }
            }
            return $size;
        }
        when 'reg-cr' | 'cr-reg' {
            return 3; # 0F 20/22 /r
        }
        when 'imm8-short' {
            return 2;
        }
    }
    return 0;
}