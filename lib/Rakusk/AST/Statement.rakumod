use v6;
use Rakusk::AST::Base;

unit module Rakusk::AST::Statement;

class LabelStmt is Statement is export {
    has $.label;
}

class DeclareStmt is Statement is export {
    has $.name;
    has $.value; # Expression
}

class ExportSymStmt is Statement is export {
    has @.symbols;
}

class ExternSymStmt is Statement is export {
    has @.symbols;
}

class ConfigStmt is Statement is export {
    has $.type;
    has $.value;
}