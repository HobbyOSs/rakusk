use v6;
use Rakusk::AST::Base;
use Rakusk::AST::Factor;

unit module Rakusk::AST::Expression;

role Expression is export {
    method eval(%env) { ... }
    method value() { ... }
}

class NumberExp does Expression is export {
    has $.value;
    method eval(%env) {
        return self;
    }
    method value() {
        return $!value;
    }
    method Int {
        return $!value if $!value ~~ Int;
        $!value.Int
    }
    method Str { $!value.Str }
}

class StringExp does Expression is export {
    has $.value;
    method eval(%env) { self }
    method value() { $!value }
    method Str { $!value }
}

class ImmExp does Expression is export {
    has Factor $.factor;
    method eval(%env) {
        my $val = $!factor.eval(%env);
        if $val ~~ Int {
            return NumberExp.new(value => $val);
        }
        if $val ~~ Str {
            # Symbol or String literal
            if %env<symbols>{$val}:exists {
                my $sym_val = %env<symbols>{$val};
                if $sym_val ~~ Int {
                    return NumberExp.new(value => $sym_val);
                }
                if $sym_val ~~ Str {
                    return StringExp.new(value => $sym_val);
                }
                return $sym_val;
            }
            return StringExp.new(value => $val);
        }
        # パス1でのサイズ計算用：未解決のシンボルは self を返して
        # 定数ではないことを示す（または NumberExp(0) を返す従来の挙動を維持するか？）
        # Grammar.rakumod でのリテラル判定に使われるため、ここでは self を返すのが望ましい
        return self;
    }
    method value() {
        my $res = self.eval({});
        if $res ~~ self {
            return $!factor.Str;
        }
        return $res.value;
    }
    method Str { $!factor.Str }
}

class MultExp does Expression is export {
    has Expression $.head;
    has @.operators; # '*', '/', '%'
    has Expression @.tails;

    method value() {
        my $res = self.eval({});
        if $res ~~ self { return 0 }
        return $res.value;
    }

    method eval(%env) {
        my $res = $!head.eval(%env);
        return self unless $res ~~ NumberExp && $res.value ~~ Int;
        
        my $val = $res.value;
        for @!operators.kv -> $i, $op {
            my $tail_res = @!tails[$i].eval(%env);
            return self unless $tail_res ~~ NumberExp && $tail_res.value ~~ Int;
            
            given $op {
                when '*' { $val *= $tail_res.value }
                when '/' {
                    return self if $tail_res.value == 0;
                    $val = ($val / $tail_res.value).Int;
                }
                when '%' {
                    return self if $tail_res.value == 0;
                    $val %= $tail_res.value;
                }
            }
        }
        return NumberExp.new(value => $val);
    }

    method Str {
        my $s = $!head.Str;
        for @!operators.kv -> $i, $op {
            $s ~= " $op " ~ @!tails[$i].Str;
        }
        $s;
    }
}

class AddExp does Expression is export {
    has Expression $.head;
    has @.operators; # '+', '-'
    has Expression @.tails;

    method value() {
        my $res = self.eval({});
        if $res ~~ self { return 0 }
        return $res.value;
    }

    method eval(%env) {
        my $res = $!head.eval(%env);
        # 完全に定数化できない場合も、部分的に定数畳み込みすることは可能だが、
        # まずは単純な実装にする
        return self unless $res ~~ NumberExp && $res.value ~~ Int;

        my $val = $res.value;
        for @!operators.kv -> $i, $op {
            my $tail_res = @!tails[$i].eval(%env);
            return self unless $tail_res ~~ NumberExp && $tail_res.value ~~ Int;

            given $op {
                when '+' { $val += $tail_res.value }
                when '-' { $val -= $tail_res.value }
            }
        }
        return NumberExp.new(value => $val);
    }

    method Str {
        my $s = $!head.Str;
        for @!operators.kv -> $i, $op {
            $s ~= " $op " ~ @!tails[$i].Str;
        }
        $s;
    }
}
