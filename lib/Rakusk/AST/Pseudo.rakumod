use v6;
use Rakusk::AST::Base;
use Rakusk::AST::Operand;
use Rakusk::AST::Expression;
use Rakusk::AST::Factor;

unit module Rakusk::AST::Pseudo;

class PseudoNode is Statement is export {
    has $.mnemonic;
    has @.operands;

}
