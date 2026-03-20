use v6;
use Rakusk::AST::Base;
use Rakusk::AST::Operand;
use Rakusk::AST::Expression;

unit module Rakusk::AST::Instruction;

class InstructionNode is Statement is export {
    has $.mnemonic;
    has @.operands;
    has %.info;
    has Int $.current_size is rw = 0;
}
