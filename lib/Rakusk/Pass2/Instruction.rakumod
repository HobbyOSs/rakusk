use v6;
use Rakusk::AST;
use Rakusk::Util;

unit role Rakusk::Pass2::Instruction;

method encode-instruction($node, %regs, %env) {
    my %info = $node.info;
    my $type = %info<type> // '';
    my $mnemonic = $node.mnemonic;

    if $type eq 'no-op' {
        return Buf.new() unless %info<opcode>;
        return Buf.new(%info<opcode>.parse-base(16));
    }
    elsif $type eq 'reg-imm8' {
        my $reg_op = $node.operands[0];
        my $imm_val = self.eval-to-int($node.operands[1], %env);
        if %info<base_opcode> {
            my $opcode = %info<base_opcode>.parse-base(16) + $reg_op.index;
            return Buf.new($opcode, $imm_val % 256);
        } else {
            my $opcode = %info<opcode>.parse-base(16);
            my $modrm = pack-modrm(mod => 3, reg => (%info<extension> // 0), rm => $reg_op.index);
            return Buf.new($opcode, $modrm, $imm_val % 256);
        }
    }
    elsif $type eq 'reg-imm16' {
        my $reg_op = $node.operands[0];
        my $imm_val = self.eval-to-int($node.operands[1], %env);
        my $opcode = %info<base_opcode>.parse-base(16) + $reg_op.index;
        return Buf.new($opcode, $imm_val % 256, ($imm_val +> 8) % 256);
    }
    elsif $type eq 'reg-reg' {
        my $dst_op = $node.operands[0];
        my $src_op = $node.operands[1];
        my $modrm = pack-modrm(mod => 3, reg => $src_op.index, rm => $dst_op.index);
        return Buf.new(%info<opcode>.parse-base(16), $modrm);
    }
    elsif $type eq 'sreg-reg' {
        my $sreg_op = $node.operands[0];
        my $reg_op = $node.operands[1];
        my $modrm = pack-modrm(mod => 3, reg => $sreg_op.index, rm => $reg_op.index);
        return Buf.new(%info<opcode>.parse-base(16), $modrm);
    }
    elsif $type eq 'reg-sreg' {
        my $reg_op = $node.operands[0];
        my $sreg_op = $node.operands[1];
        my $modrm = pack-modrm(mod => 3, reg => $sreg_op.index, rm => $reg_op.index);
        return Buf.new(%info<opcode>.parse-base(16), $modrm);
    }
    elsif $type eq 'reg-mem' || $type eq 'mem-reg' {
        my $reg_op = $node.operands.grep(Register)[0];
        my $mem_op = $node.operands.grep(Memory)[0];
        my ($mod, $rm, $disp_bytes) = self.encode-mem-op($mem_op, %env);
        my $modrm = pack-modrm(mod => $mod, reg => $reg_op.index, rm => $rm);
        my $bin = Buf.new(%info<opcode>.parse-base(16), $modrm);
        $bin ~= $disp_bytes if $disp_bytes;
        return $bin;
    }
    elsif $type eq 'short-jump' {
        my $target = self.eval-to-int($node.operands[0], %env);
        my $offset = $target - (%env<PC> + 2);
        return Buf.new(%info<opcode>.parse-base(16), $offset % 256);
    }
    elsif $type eq 'near-jump' {
        my $target = self.eval-to-int($node.operands[0], %env);
        # JMP rel16 (E9) is 3 bytes in 16-bit mode
        # JMP rel32 (E9) is 5 bytes in 32-bit mode
        my $inst_size = (self.bit_mode == 16 ?? 3 !! 5);
        my $offset = $target - (%env<PC> + $inst_size);
        my $bin = Buf.new(%info<opcode>.parse-base(16));
        if self.bit_mode == 16 {
            $bin.push($offset % 256);
            $bin.push(($offset +> 8) % 256);
        } else {
            $bin.push($offset % 256);
            $bin.push(($offset +> 8) % 256);
            $bin.push(($offset +> 16) % 256);
            $bin.push(($offset +> 24) % 256);
        }
        return $bin;
    }
    elsif $type eq 'far-jump' {
        # EA /ptr16:16 or ptr16:32
        my $op = $node.operands[0];
        my $selector = self.eval-to-int($op.selector, %env);
        my $offset = self.eval-to-int($op.offset, %env);
        
        my $bin = Buf.new();
        # If offset is 32-bit, we might need 66h prefix in 16-bit mode
        # For now let's assume if bit_mode is 32, we use 32-bit offset.
        # Or if harib00i uses DWORD JMP, we should use 32-bit offset.
        my $use_32bit_offset = (self.bit_mode == 32);
        # In harib00i: JMP DWORD 2*8:0x0000001b
        # We need a way to detect DWORD.
        
        $bin.push(%info<opcode>.parse-base(16));
        if $use_32bit_offset {
            $bin.push($offset % 256, ($offset +> 8) % 256, ($offset +> 16) % 256, ($offset +> 24) % 256);
        } else {
            $bin.push($offset % 256, ($offset +> 8) % 256);
        }
        $bin.push($selector % 256, ($selector +> 8) % 256);
        
        if self.bit_mode == 16 && $use_32bit_offset {
            $bin = Buf.new(0x66) ~ $bin;
        }
        return $bin;
    }
    elsif $type eq 'imm8' {
        my $val = self.eval-to-int($node.operands[0], %env);
        return Buf.new(%info<opcode>.parse-base(16), $val % 256);
    }
    elsif $type eq 'short-imm' {
        my $imm_val = self.eval-to-int($node.operands[1], %env);
        my $bin = Buf.new(%info<opcode>.parse-base(16));
        if (%info<width> // 8) == 8 {
            $bin.push($imm_val % 256);
        } else {
            $bin.push($imm_val % 256, ($imm_val +> 8) % 256);
            if self.bit_mode == 32 && %info<width> == 32 {
                 $bin.push(($imm_val +> 16) % 256, ($imm_val +> 24) % 256);
            }
        }
        return $bin;
    }
    elsif $type eq 'imm8-short' {
        my $imm_val = self.eval-to-int($node.operands[0], %env);
        return Buf.new(%info<opcode>.parse-base(16), $imm_val % 256);
    }
    elsif $type eq 'reg-cr' || $type eq 'cr-reg' {
        my $reg_op = $node.operands.grep({ $_ ~~ Register && %REGS_DATA{$_.name.uc}<type> ne 'control' })[0];
        my $cr_op = $node.operands.grep({ $_ ~~ Register && %REGS_DATA{$_.name.uc}<type> eq 'control' })[0];
        my $modrm;
        if $type eq 'reg-cr' {
             # MOV reg, CRx -> 0F 20 /r (reg is rm, CRx is reg field)
             $modrm = pack-modrm(mod => 3, reg => $cr_op.index, rm => $reg_op.index);
        } else {
             # MOV CRx, reg -> 0F 22 /r (CRx is reg field, reg is rm)
             $modrm = pack-modrm(mod => 3, reg => $cr_op.index, rm => $reg_op.index);
        }
        return Buf.new(0x0F, %info<opcode>.parse-base(16) % 256, $modrm);
    }
    elsif $mnemonic eq 'ADD' || $mnemonic eq 'CMP' {
        my $opcode = %info<opcode>.parse-base(16);
        if $type eq 'reg-imm8' {
            my $reg_op = $node.operands[0];
            my $imm = self.eval-to-int($node.operands[1], %env);
            my $modrm = pack-modrm(mod => 3, reg => %info<extension>, rm => $reg_op.index);
            return Buf.new($opcode, $modrm, $imm % 256);
        }
        elsif $type eq 'reg-reg' {
            my $dst_op = $node.operands[0];
            my $src_op = $node.operands[1];
            my $modrm = pack-modrm(mod => 3, reg => $src_op.index, rm => $dst_op.index);
            return Buf.new($opcode, $modrm);
        }
    }
    return Buf.new();
}

method encode-mem-op($mem, %env) {
    return (0, 0, Buf.new()) unless $mem ~~ Memory;
    my $base = $mem.base ~~ Register ?? $mem.base.Str.uc !! ($mem.base // '');
    my $index = $mem.index ~~ Register ?? $mem.index.Str.uc !! ($mem.index // '');
    my $dv = self.eval-to-int($mem.disp, %env);
    
    my $rm;
    if $base eq 'BX' && $index eq 'SI' { $rm = 0; }
    elsif $base eq 'BX' && $index eq 'DI' { $rm = 1; }
    elsif $base eq 'BP' && $index eq 'SI' { $rm = 2; }
    elsif $base eq 'BP' && $index eq 'DI' { $rm = 3; }
    elsif $base eq '' && $index eq 'SI' { $rm = 4; }
    elsif $base eq 'SI' && $index eq '' { $rm = 4; }
    elsif $base eq '' && $index eq 'DI' { $rm = 5; }
    elsif $base eq 'DI' && $index eq '' { $rm = 5; }
    elsif $base eq 'BP' && $index eq '' { $rm = 6; }
    elsif $base eq 'BX' && $index eq '' { $rm = 7; }
    else {
        return (0, 0, Buf.new());
    }

    my $mod;
    my $disp_bytes = Buf.new();
    if $dv == 0 && $rm != 6 {
        $mod = 0;
    } elsif $dv.abs <= 127 {
        $mod = 1;
        $disp_bytes.push($dv % 256);
    } else {
        $mod = 2;
        $disp_bytes.push($dv % 256);
        $disp_bytes.push(($dv +> 8) % 256);
    }
    
    return ($mod, $rm, $disp_bytes);
}