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
            my $reg_field = %info<extension> // $reg_op.index;
            my $modrm = pack-modrm(mod => 3, reg => $reg_field, rm => $reg_op.index);
            my $bin = Buf.new();
            if self.bit_mode == 16 && $reg_op.width == 32 {
                $bin.push(0x66);
            }
            $bin.push($opcode, $modrm, $imm_val % 256);
            return $bin;
        }
    }
    elsif $type eq 'reg-imm16' {
        my $reg_op = $node.operands[0];
        my $imm_val = self.eval-to-int($node.operands[1], %env);
        my $bin = Buf.new();
        if self.bit_mode == 16 && $reg_op.width == 32 {
            $bin.push(0x66);
        }
        if %info<base_opcode> {
            my $opcode = %info<base_opcode>.parse-base(16) + $reg_op.index;
            $bin.push($opcode);
            $bin.push($imm_val % 256, ($imm_val +> 8) % 256);
            if $reg_op.width == 32 {
                $bin.push(($imm_val +> 16) % 256, ($imm_val +> 24) % 256);
            }
        } else {
            my $opcode = %info<opcode>.parse-base(16);
            my $reg_field = %info<extension> // $reg_op.index;
            my $modrm = pack-modrm(mod => 3, reg => $reg_field, rm => $reg_op.index);
            $bin.push($opcode, $modrm);
            $bin.push($imm_val % 256, ($imm_val +> 8) % 256);
            if $reg_op.width == 32 {
                $bin.push(($imm_val +> 16) % 256, ($imm_val +> 24) % 256);
            }
        }
        return $bin;
    }
    elsif $type eq 'reg-reg' {
        my $dst_op = $node.operands[0];
        my $src_op = $node.operands[1];
        my $modrm = pack-modrm(mod => 3, reg => $src_op.index, rm => $dst_op.index);
        my $bin = Buf.new();
        if self.bit_mode == 16 && ($dst_op.width == 32 || $src_op.width == 32) {
            $bin.push(0x66);
        }
        $bin ~= Buf.new(%info<opcode>.parse-base(16), $modrm);
        return $bin;
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
        my ($mod, $rm, $disp_bytes, $sib, $needs_67) = self.encode_mem_op($mem_op, %env);
        my $modrm = pack-modrm(mod => $mod, reg => $reg_op.index, rm => $rm);
        my $bin = Buf.new();
        if $needs_67 { $bin.push(0x67); }
        if self.bit_mode == 16 && $reg_op.width == 32 {
            $bin.push(0x66);
        }
        $bin ~= Buf.new(%info<opcode>.parse-base(16), $modrm);
        $bin ~= $sib if $sib;
        $bin ~= $disp_bytes if $disp_bytes;
        return $bin;
    }
    elsif $type eq 'mem-imm8' || $type eq 'mem-imm16' {
        my $mem_op = $node.operands.grep(Memory)[0];
        my $imm_val = self.eval-to-int($node.operands[1], %env);
        my ($mod, $rm, $disp_bytes, $sib, $needs_67) = self.encode_mem_op($mem_op, %env);
        my $modrm = pack-modrm(mod => $mod, reg => (%info<extension> // 0), rm => $rm);
        my $bin = Buf.new();
        if $needs_67 { $bin.push(0x67); }
        if self.bit_mode == 16 && (($mem_op.size_prefix // '') eq 'DWORD' || $type eq 'mem-imm32') {
            $bin.push(0x66);
        }
        $bin ~= Buf.new(%info<opcode>.parse-base(16), $modrm);
        $bin ~= $sib if $sib;
        $bin ~= $disp_bytes if $disp_bytes;
        if $type eq 'mem-imm8' {
            $bin.push($imm_val % 256);
        } else {
            $bin.push($imm_val % 256, ($imm_val +> 8) % 256);
            if $bin[0] == 0x66 || $bin[1] == 0x66 || self.bit_mode == 32 {
                 $bin.push(($imm_val +> 16) % 256, ($imm_val +> 24) % 256);
            }
        }
        return $bin;
    }
    elsif $type eq 'short-jump' {
        my $target = self.eval-to-int($node.operands[0], %env);
        my $offset = $target - (%env<PC> + 2);
        return Buf.new(%info<opcode>.parse-base(16), $offset % 256);
    }
    elsif $type eq 'near-jump' {
        my $target = self.eval-to-int($node.operands[0], %env);
        my $inst_size = (self.bit_mode == 16 ?? 3 !! 5);
        my $offset = $target - (%env<PC> + $inst_size);
        my $bin = Buf.new(%info<opcode>.parse-base(16));
        if self.bit_mode == 16 {
            $bin.push($offset % 256, ($offset +> 8) % 256);
        } else {
            $bin.push($offset % 256, ($offset +> 8) % 256, ($offset +> 16) % 256, ($offset +> 24) % 256);
        }
        return $bin;
    }
    elsif $type eq 'far-jump' {
        my $op = $node.operands[0];
        my $selector = self.eval-to-int($op.selector, %env);
        my $offset = self.eval-to-int($op.offset, %env);
        my $bin = Buf.new();
        my $use_32bit_offset = (self.bit_mode == 32 || ($op.size_prefix // '') eq 'DWORD');
        if self.bit_mode == 16 && $use_32bit_offset { $bin.push(0x66); }
        $bin.push(%info<opcode>.parse-base(16));
        if $use_32bit_offset {
            $bin.push($offset % 256, ($offset +> 8) % 256, ($offset +> 16) % 256, ($offset +> 24) % 256);
        } else {
            $bin.push($offset % 256, ($offset +> 8) % 256);
        }
        $bin.push($selector % 256, ($selector +> 8) % 256);
        return $bin;
    }
    elsif $type eq 'imm8' {
        my $val = self.eval-to-int($node.operands[0], %env);
        return Buf.new(%info<opcode>.parse-base(16), $val % 256);
    }
    elsif $type eq 'short-imm' {
        my $reg = $node.operands[0];
        my $imm_val = self.eval-to-int($node.operands[1], %env);
        my $bin = Buf.new();
        if self.bit_mode == 16 && $reg.width == 32 { $bin.push(0x66); }
        $bin.push(%info<opcode>.parse-base(16));
        if (%info<width> // 8) == 8 { $bin.push($imm_val % 256); }
        elsif %info<width> == 16 { $bin.push($imm_val % 256, ($imm_val +> 8) % 256); }
        else { $bin.push($imm_val % 256, ($imm_val +> 8) % 256, ($imm_val +> 16) % 256, ($imm_val +> 24) % 256); }
        return $bin;
    }
    elsif $type eq 'imm8-short' {
        my $imm_val = self.eval-to-int($node.operands[0], %env);
        return Buf.new(%info<opcode>.parse-base(16), $imm_val % 256);
    }
    elsif $type eq 'reg-cr' || $type eq 'cr-reg' {
        my $reg_op = $node.operands.grep({ $_ ~~ Register && !$_.is-control })[0];
        my $cr_op = $node.operands.grep({ $_ ~~ Register && $_.is-control })[0];
        my $modrm = pack-modrm(mod => 3, reg => $cr_op.index, rm => $reg_op.index);
        return Buf.new(0x0F, ($type eq 'reg-cr' ?? 0x20 !! 0x22), $modrm);
    }
    elsif $type eq 'mem' {
        my $mem_op = $node.operands[0];
        my ($mod, $rm, $disp_bytes, $sib, $needs_67) = self.encode_mem_op($mem_op, %env);
        my $modrm = pack-modrm(mod => $mod, reg => (%info<extension> // 0), rm => $rm);
        my $bin = Buf.new();
        if $needs_67 { $bin.push(0x67); }
        my $op_hex = %info<opcode> // '';
        while $op_hex.chars >= 2 {
            $bin.push($op_hex.substr(0, 2).parse-base(16));
            $op_hex = $op_hex.substr(2);
        }
        $bin.push($modrm);
        $bin ~= $sib if $sib;
        $bin ~= $disp_bytes if $disp_bytes;
        return $bin;
    }
    elsif $mnemonic eq 'ADD' || $mnemonic eq 'SUB' || $mnemonic eq 'CMP' || $mnemonic eq 'AND' || $mnemonic eq 'OR' || $mnemonic eq 'XOR' {
        my $opcode_str = %info<opcode> // '00';
        my $opcode = $opcode_str.parse-base(16);
        if $type eq 'reg-imm8' {
            my $reg_op = $node.operands[0];
            my $imm = self.eval-to-int($node.operands[1], %env);
            my $bin = Buf.new();
            if self.bit_mode == 16 && $reg_op.width == 32 { $bin.push(0x66); }
            my $modrm = pack-modrm(mod => 3, reg => (%info<extension> // 0), rm => $reg_op.index);
            $bin.push($opcode, $modrm, $imm % 256);
            return $bin;
        }
        elsif $type eq 'reg-reg' {
            my $dst_op = $node.operands[0];
            my $src_op = $node.operands[1];
            my $bin = Buf.new();
            if self.bit_mode == 16 && ($dst_op.width == 32 || $src_op.width == 32) { $bin.push(0x66); }
            my $modrm = pack-modrm(mod => 3, reg => $src_op.index, rm => $dst_op.index);
            $bin.push($opcode, $modrm);
            return $bin;
        }
        elsif $type eq 'reg-mem' || $type eq 'mem-reg' {
            my $reg_op = $node.operands.grep(Register)[0];
            my $mem_op = $node.operands.grep(Memory)[0];
            my ($mod, $rm, $disp_bytes, $sib, $needs_67) = self.encode_mem_op($mem_op, %env);
            my $modrm = pack-modrm(mod => $mod, reg => $reg_op.index, rm => $rm);
            my $bin = Buf.new();
            if $needs_67 { $bin.push(0x67); }
            if self.bit_mode == 16 && $reg_op.width == 32 { $bin.push(0x66); }
            $bin.push($opcode, $modrm);
            $bin ~= $sib if $sib;
            $bin ~= $disp_bytes if $disp_bytes;
            return $bin;
        }
    }
    elsif $type eq 'reg-reg-imm8' || $type eq 'reg-reg-imm16' {
        my $dst = $node.operands[0];
        my $src = $node.operands[1];
        my $imm = self.eval-to-int($node.operands[2], %env);
        my $bin = Buf.new();
        if self.bit_mode == 16 && ($dst.width == 32 || $src.width == 32) { $bin.push(0x66); }
        my $opcode = %info<opcode>.parse-base(16);
        my $modrm = pack-modrm(mod => 3, reg => $dst.index, rm => $src.index);
        $bin.push($opcode, $modrm);
        if $type eq 'reg-reg-imm8' { $bin.push($imm % 256); }
        else {
            $bin.push($imm % 256, ($imm +> 8) % 256);
            if $dst.width == 32 { $bin.push(($imm +> 16) % 256, ($imm +> 24) % 256); }
        }
        return $bin;
    }
    elsif $type eq 'reg-reg-2' {
        my $dst = $node.operands[0];
        my $src = $node.operands[1];
        my $bin = Buf.new();
        if self.bit_mode == 16 && ($dst.width == 32 || $src.width == 32) { $bin.push(0x66); }
        my $op_hex = %info<opcode>;
        while $op_hex.chars >= 2 {
            $bin.push($op_hex.substr(0, 2).parse-base(16));
            $op_hex = $op_hex.substr(2);
        }
        my $modrm = pack-modrm(mod => 3, reg => $dst.index, rm => $src.index);
        $bin.push($modrm);
        return $bin;
    }
    return Buf.new();
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