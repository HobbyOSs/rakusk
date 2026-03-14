use v6;
unit module Rakusk::Pass2;
use Rakusk::AST;
use Rakusk::Util;

class Pass2 is export {
    has @.ast;
    has Buf $.output = Buf.new();

    method assemble(%regs, %symbols = {}) {
        my $pc = 0;
        $!output = Buf.new();
        for @!ast -> $node {
            if $node ~~ PseudoNode && $node.mnemonic eq 'ORG' {
                my $val = $node.operands[0];
                $pc = self!eval-to-int($val, { symbols => %symbols, PC => $pc });
                next;
            }

            my %env = symbols => %symbols, PC => $pc;
            my $bin = self!encode-node($node, %regs, %env);

            if $bin.defined {
                $!output ~= $bin;
                $pc += $bin.elems;
            }
        }
        return $!output;
    }

    method !encode-node($node, %regs, %env) {
        if $node ~~ InstructionNode {
            return self!encode-instruction($node, %regs, %env);
        }
        elsif $node ~~ PseudoNode {
            return self!encode-pseudo($node, %env);
        }
        return Buf.new();
    }

    method !encode-instruction($node, %regs, %env) {
        my %info = $node.info;
        my $type = %info<type> // '';
        my $mnemonic = $node.mnemonic;

        if $type eq 'no-op' {
            return Buf.new() unless %info<opcode>;
            return Buf.new(%info<opcode>.parse-base(16));
        }
        elsif $type eq 'reg-imm8' {
            my $reg_op = $node.operands[0];
            my $imm_val = self!eval-to-int($node.operands[1], %env);
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
            my $imm_val = self!eval-to-int($node.operands[1], %env);
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
            my ($mod, $rm, $disp_bytes) = self!encode-mem-op($mem_op, %env);
            my $modrm = pack-modrm(mod => $mod, reg => $reg_op.index, rm => $rm);
            my $bin = Buf.new(%info<opcode>.parse-base(16), $modrm);
            $bin ~= $disp_bytes if $disp_bytes;
            return $bin;
        }
        elsif $type eq 'short-jump' {
            my $target = self!eval-to-int($node.operands[0], %env);
            my $offset = $target - (%env<PC> + 2);
            return Buf.new(%info<opcode>.parse-base(16), $offset % 256);
        }
        elsif $type eq 'imm8' {
            my $val = self!eval-to-int($node.operands[0], %env);
            return Buf.new(%info<opcode>.parse-base(16), $val % 256);
        }
        elsif $type eq 'short-imm' {
            my $imm_val = self!eval-to-int($node.operands[1], %env);
            return Buf.new(%info<opcode>.parse-base(16), $imm_val % 256);
        }
        elsif $mnemonic eq 'ADD' || $mnemonic eq 'CMP' {
            my $opcode = %info<opcode>.parse-base(16);
            if $type eq 'reg-imm8' {
                my $reg_op = $node.operands[0];
                my $imm = self!eval-to-int($node.operands[1], %env);
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

    method !encode-mem-op($mem, %env) {
        return (0, 0, Buf.new()) unless $mem ~~ Memory;
        my $base = $mem.base ~~ Register ?? $mem.base.Str.uc !! ($mem.base // '');
        my $index = $mem.index ~~ Register ?? $mem.index.Str.uc !! ($mem.index // '');
        my $dv = self!eval-to-int($mem.disp, %env);
        
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

    method !encode-pseudo($node, %env) {
        my $bin = Buf.new();
        my $current_pc = %env<PC> // 0;

        given $node.mnemonic {
            when 'DB' {
                for $node.operands -> $op {
                    my $val = self!eval-to-any($op, %env);
                    if $val ~~ Int {
                        $bin.push($val % 256);
                    } elsif $val ~~ Str {
                        if $val.chars > 1 {
                            $bin ~= $val.encode('ascii');
                        } else {
                            $bin.push($val.ord % 256);
                        }
                    }
                }
            }
            when 'DW' {
                for $node.operands -> $op {
                    my $val = self!eval-to-int($op, %env);
                    $bin.push($val % 256);
                    $bin.push(($val +> 8) % 256);
                }
            }
            when 'DD' {
                for $node.operands -> $op {
                    my $val = self!eval-to-int($op, %env);
                    $bin.push($val % 256);
                    $bin.push(($val +> 8) % 256);
                    $bin.push(($val +> 16) % 256);
                    $bin.push(($val +> 24) % 256);
                }
            }
            when 'RESB' {
                my $size = self!eval-to-int($node.operands[0], %env);
                $bin.push(0) for 1..$size;
            }
            when 'ALIGNB' {
                my $boundary = self!eval-to-int($node.operands[0], %env);
                my $padding = ($boundary - ($current_pc % $boundary)) % $boundary;
                $bin.push(0) for 1..$padding;
            }
        }
        return $bin;
    }

    method !eval-to-int($op, %env) {
        my $res = self!eval-to-any($op, %env);
        return $res if $res ~~ Int;
        return 0;
    }

    method !eval-to-any($op, %env) {
        if $op ~~ Immediate {
            my $res = $op.expr.eval(%env);
            if $res ~~ NumberExp {
                return $res.value;
            } else {
                return $op.expr.factor.eval(%env);
            }
        } elsif $op ~~ Expression {
            my $res = $op.eval(%env);
            if $res ~~ NumberExp {
                return $res.value;
            }
            return $res;
        } elsif $op ~~ Int | Str {
            return $op;
        }
        return 0;
    }
}