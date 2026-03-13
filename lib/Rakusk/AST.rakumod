use v6;
unit module Rakusk::AST;

class Node is export { }

class InstructionNode is Node is export {
    has $.mnemonic;
    has @.operands;
    has %.info;

    method encode(%regs) {
        if %!info<type> eq 'no-op' {
            return Buf.new(%!info<opcode>.parse-base(16));
        }
        elsif %!info<type> eq 'reg-imm8' {
            my $reg_name = @!operands[0].uc;
            my $imm_val  = @!operands[1];
            my $opcode = %!info<base_opcode>.parse-base(16) + %regs{$reg_name};
            return Buf.new($opcode, $imm_val);
        }
        return Buf.new();
    }
}

class PseudoNode is Node is export {
    has $.mnemonic;
    has @.operands;

    method encode($current_pc = 0) {
        my $bin = Buf.new();
        given $!mnemonic {
            when 'DB' {
                for @!operands -> $op {
                    if $op ~~ Str {
                        $bin ~= $op.encode('ascii');
                    } else {
                        $bin.push($op % 256);
                    }
                }
            }
            when 'DW' {
                for @!operands -> $op {
                    $bin.push($op % 256);
                    $bin.push(($op +> 8) % 256);
                }
            }
            when 'DD' {
                for @!operands -> $op {
                    $bin.push($op % 256);
                    $bin.push(($op +> 8) % 256);
                    $bin.push(($op +> 16) % 256);
                    $bin.push(($op +> 24) % 256);
                }
            }
            when 'RESB' {
                my $size = @!operands[0];
                $bin.push(0) for 1..$size;
            }
            when 'ALIGNB' {
                my $boundary = @!operands[0];
                my $padding = ($boundary - ($current_pc % $boundary)) % $boundary;
                $bin.push(0) for 1..$padding;
            }
            when 'ORG' {
                # ORG itself doesn't emit bytes, but changes the starting address.
                # In simple cases, it's handled in Pass1 to set initial PC.
            }
        }
        return $bin;
    }
}
