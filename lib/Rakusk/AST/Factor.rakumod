use v6;
use Rakusk::AST::Base;

unit module Rakusk::AST::Factor;

role Factor is export {
    method eval(%env) { ... }
}

class NumberFactor does Factor is export {
    has $.value;
    method eval(%env) {
        return $!value;
    }
    method Str { $!value.Str }
}

class HexFactor does Factor is export {
    has $.value;
    method eval(%env) {
        my $v = $!value;
        if $v.match(/^:i 0x(<[0..9a..fA..F]>+)$/) {
            return $0.Str.parse-base(16);
        }
        return $!value.parse-base(16);
    }
    method Str { $!value }
}

class CharFactor does Factor is export {
    has $.value;
    method eval(%env) {
        # 'A' -> 65
        my $v = $!value;
        if $v ~~ Match { $v = $v.Str }
        
        if $v.chars == 1 {
            return $v.ord;
        }
        # Fallback if quotes are still there
        if $v.match(/^['"'|"'"]/) {
             $v = $v.substr(1, *-1);
        }
        return $v.ord;
    }
    method Str { $!value }
}

class IdentFactor does Factor is export {
    has $.value;
    method eval(%env) {
        if $!value eq '$' {
            return %env<PC> // 0;
        }
        if %env<symbols>{$!value}:exists {
            return %env<symbols>{$!value};
        }
        # 未解決の場合は名前を返すか、Failureを返す
        return $!value;
    }
    method Str { $!value }
}

class StringFactor does Factor is export {
    has $.value;
    method eval(%env) {
        # 文字列リテラルはそのままでもよいが、
        # クォートを外した値を返す
        if $!value.match(/^['"'|"'"]/) {
            return $!value.substr(1, *-1);
        }
        return $!value;
    }
    method Str { $!value }
}