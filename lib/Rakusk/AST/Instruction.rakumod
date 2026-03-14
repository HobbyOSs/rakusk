use v6;
use Rakusk::AST::Base;
use Rakusk::AST::Operand;
use Rakusk::AST::Expression;

unit module Rakusk::AST::Instruction;

class InstructionNode is Statement is export {
    has $.mnemonic;
    has @.operands;
    has %.info;

    method encode(%regs, %env = {}) {
        if %!info<type> eq 'no-op' {
            return Buf.new(%!info<opcode>.parse-base(16));
        }
        elsif %!info<type> eq 'reg-imm8' {
            my $reg_name = @!operands[0].Str.uc;
            
            # オペランドが Immediate の場合、その中の Expression を eval する
            my $imm_val = 0;
            my $op1 = @!operands[1];
            if $op1 ~~ Immediate {
                my $res = $op1.expr.eval(%env);
                if $res ~~ NumberExp {
                    $imm_val = $res.value;
                }
            } else {
                $imm_val = $op1.Int;
            }

            my $opcode = %!info<base_opcode>.parse-base(16) + %regs{$reg_name};
            return Buf.new($opcode, $imm_val % 256);
        }
        return Buf.new();
    }
}