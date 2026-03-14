use v6;
use Rakusk::AST::Base;
use Rakusk::AST::Expression;

unit module Rakusk::AST::Operand;

class Register does Operand is export {
    has $.name;
    has $.width;
    has $.index;
    has $.type; # 'general', 'segment', 'control'
    method Str { $!name }
    method is-segment {
        return ($!type // '') eq 'segment' || $!name.uc ~~ /^(ES|CS|SS|DS|FS|GS)$/;
    }
    method is-control {
        return ($!type // '') eq 'control' || $!name.uc ~~ /^CR[0234]$/;
    }
}

class Immediate does Operand is export {
    has Expression $.expr;
    method value() {
        return $!expr.value;
    }
    method Int {
        # eval して定数になればその値を返す
        # 環境が必要な場合は外部から eval を呼ぶべき
        # ここではフォールバックとして単純な eval (空の環境) を試みる
        my $res = $!expr.eval({});
        return $res.value if $res ~~ NumberExp;
        return 0;
    }
    method Str { $!expr.Str }
}

class Memory does Operand is export {
    has $.base is rw;         # Register or Str
    has $.index is rw;        # Register or Str
    has $.scale is rw = 1;    # Int
    has $.disp is rw = 0;     # Expression
    has $.size_prefix is rw;  # BYTE, WORD, DWORD etc.

    method Str {
        my $s = $!size_prefix ?? $!size_prefix ~ " " !! "";
        $s ~= "[";
        $s ~= $!base.Str if $!base;
        if $!index {
            $s ~= "+" if $!base;
            $s ~= $!index.Str;
            $s ~= "*" ~ $!scale if $!scale != 1;
        }
        if $!disp {
            my $disp_str = $!disp.Str;
            if $disp_str.match(/^\-/) {
                $s ~= $disp_str;
            } else {
                $s ~= "+" ~ $disp_str if $!base || $!index;
                $s ~= $disp_str unless $!base || $!index;
            }
        }
        $s ~= "]";
        $s;
    }
}

class SegmentedAddress does Operand is export {
    has Expression $.selector;
    has Expression $.offset;
    has $.size_prefix is rw;

    method Str {
        my $s = $!size_prefix ?? $!size_prefix ~ " " !! "";
        $s ~= $!selector.Str ~ ":" ~ $!offset.Str;
        $s;
    }
}