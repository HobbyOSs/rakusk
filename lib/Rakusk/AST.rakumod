use v6;
unit module Rakusk::AST;

class Node is export { }

role Operand is export { }

class Register is Operand is export {
    has $.name;
    method Str { $!name }
}

class Immediate is Operand is export {
    has $.value;
    method Int {
        return $!value.Int if $!value ~~ Numeric;
        return $!value.Int if $!value ~~ Str && $!value.match(/^\-?\d+$/);
        return $!value.parse-base(16) if $!value ~~ Str && $!value.match(/^:i 0x[<[0..9a..fA..F]>+]$/);
        # 文字列リテラルの場合（最初の文字を数値として返すなど）
        # 本来は呼び出し側で文字列かどうか判断すべきだが、フェイルセーフとして
        return 0;
    }
    method Str { $!value.Str }
}

class Memory is Operand is export {
    has $.base is rw;         # Register or Str
    has $.index is rw;        # Register or Str
    has $.scale is rw = 1;    # Int
    has $.disp is rw = 0;     # Int or Str

    method Str {
        my $s = "[";
        $s ~= $!base.Str if $!base;
        if $!index {
            $s ~= "+" if $!base;
            $s ~= $!index.Str;
            $s ~= "*" ~ $!scale if $!scale != 1;
        }
        if $!disp {
            if $!disp ~~ Int {
                $s ~= ($!disp >= 0 ?? "+" !! "") ~ $!disp;
            } else {
                $s ~= "+" ~ $!disp;
            }
        }
        $s ~= "]";
        $s;
    }
}

class Statement is Node is export { }

class LabelStmt is Statement is export {
    has $.label;
}

class DeclareStmt is Statement is export {
    has $.name;
    has $.value;
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

class InstructionNode is Statement is export {
    has $.mnemonic;
    has @.operands;
    has %.info;

    method encode(%regs) {
        if %!info<type> eq 'no-op' {
            return Buf.new(%!info<opcode>.parse-base(16));
        }
        elsif %!info<type> eq 'reg-imm8' {
            my $reg_name = @!operands[0].Str.uc;
            my $imm_val  = @!operands[1].Int;
            my $opcode = %!info<base_opcode>.parse-base(16) + %regs{$reg_name};
            return Buf.new($opcode, $imm_val);
        }
        return Buf.new();
    }
}

class PseudoNode is Statement is export {
    has $.mnemonic;
    has @.operands;

    method encode($current_pc = 0) {
        my $bin = Buf.new();
        given $!mnemonic {
            when 'DB' {
                for @!operands -> $op {
                    my $val = $op ~~ Immediate ?? $op.value !! $op;
                    if $val ~~ Str && $val.match(/^['"'|"'"]/) {
                        # クォートされた文字列
                        my $content = $val.substr(1, *-1);
                        $bin ~= $content.encode('ascii');
                    }
                    elsif $val ~~ Str && !$val.match(/^\-?\d+$/) && !$val.match(/^:i 0x/) {
                        # その他の文字列（クォートなしの文字列リテラルなど）
                        $bin ~= $val.encode('ascii');
                    }
                    else {
                        my $num = $op ~~ Immediate ?? $op.Int !! $op.Int;
                        $bin.push($num % 256);
                    }
                }
            }
            when 'DW' {
                for @!operands -> $op {
                    my $val = $op ~~ Immediate ?? $op.Int !! $op.Int;
                    $bin.push($val % 256);
                    $bin.push(($val +> 8) % 256);
                }
            }
            when 'DD' {
                for @!operands -> $op {
                    my $val = $op ~~ Immediate ?? $op.Int !! $op.Int;
                    $bin.push($val % 256);
                    $bin.push(($val +> 8) % 256);
                    $bin.push(($val +> 16) % 256);
                    $bin.push(($val +> 24) % 256);
                }
            }
            when 'RESB' {
                my $op = @!operands[0];
                my $size = $op ~~ Immediate ?? $op.Int !! $op.Int;
                $bin.push(0) for 1..$size;
            }
            when 'ALIGNB' {
                my $op = @!operands[0];
                my $boundary = $op ~~ Immediate ?? $op.Int !! $op.Int;
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
