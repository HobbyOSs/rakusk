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