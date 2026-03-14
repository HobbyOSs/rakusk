use v6;
unit module Rakusk::Pass2;
use Rakusk::AST;
use Rakusk::Util;

class Pass2 is export {
    has @.ast;
    has Buf $.output = Buf.new();

    method assemble(%regs, %symbols = {}) {
        my $pc = 0;
        for @!ast -> $node {
            if $node ~~ PseudoNode && $node.mnemonic eq 'ORG' {
                my $val = $node.operands[0];
                $pc = $val ~~ Immediate ?? $val.Int !! $val.Int;
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
        if %info<type> eq 'no-op' {
            return Buf.new(%info<opcode>.parse-base(16));
        }
        elsif %info<type> eq 'reg-imm8' {
            my $reg_name = $node.operands[0].Str.uc;
            my $imm_val = self!eval-to-int($node.operands[1], %env);
            my $opcode = %info<base_opcode>.parse-base(16) + %regs{$reg_name};
            return Buf.new($opcode, $imm_val % 256);
        }
        elsif %info<type> eq 'reg-reg' {
            # 例: MOV EAX, EBX -> opcode 89, ModR/M C3
            # operands[0] が dst (r/m), operands[1] が src (reg)
            my $dst_reg = %regs{$node.operands[0].name.uc};
            my $src_reg = %regs{$node.operands[1].name.uc};

            # レジスタ間転送なので Mod=3
            my $modrm = pack-modrm(mod => 3, reg => $src_reg, rm => $dst_reg);
            
            return Buf.new(%info<opcode>.parse-base(16), $modrm);
        }
        return Buf.new();
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
