use v6;
unit module Rakusk::Pass1;
use Rakusk::AST;

class Pass1 is export {
    has %.symbols;
    has @.ast;
    has Int $.pc = 0;
    has Int $.bit_mode = 16;

    method evaluate(@ast, %regs) {
        @!ast = @ast;
        
        # パス1: ラベル・定数の収集とPCの計算
        $!pc = 0;
        $!bit_mode = 16;
        for @!ast -> $node {
            my %env = symbols => %!symbols, PC => $!pc;

            if $node ~~ LabelStmt {
                my $label = $node.label;
                $label ~~ s/\:$//;
                %!symbols{$label} = $!pc;
                next;
            }
            if $node ~~ DeclareStmt {
                my $val = self!eval-to-any($node.value, %env);
                %!symbols{$node.name} = $val;
                next;
            }

            if $node ~~ ConfigStmt {
                if $node.type eq 'BITS' {
                    $!bit_mode = self!eval-to-int($node.value, %env);
                }
                next;
            }

            if $node ~~ InstructionNode {
                self!process-instruction($node, %regs, %env);
            }
            elsif $node ~~ PseudoNode {
                self!process-pseudo($node, %env);
            }
        }
        return self;
    }

    method !process-instruction($node, %regs, %env) {
        my $mnemonic = $node.mnemonic;
        my @operands = $node.operands;

        # ジャンプ命令判定
        if $mnemonic ~~ /^[ J | CALL ]/ {
            self!process-JMP($node, %regs, %env);
            return;
        }

        # TODO: 将来的にはハンドラマップ形式にするが、まずはシンプルに分岐
        if $mnemonic eq 'MOV' {
            self!process-MOV($node, %regs, %env);
        }
        else {
            # デフォルト処理（1バイト命令など）
            my $size = self!size-of-instruction($node, %regs, %env);
            $!pc += $size;
        }
    }

    method !process-MOV($node, %regs, %env) {
        # gosk のロジックを参考に、オペランドに応じたサイズ計算を強化する準備
        # 現在は既存の size-of-instruction に委譲
        my $size = self!size-of-instruction($node, %regs, %env);
        $!pc += $size;
    }

    method !process-JMP($node, %regs, %env) {
        my $mnemonic = $node.mnemonic;
        my $size = self!estimate-jump-size($mnemonic, $!bit_mode);
        $!pc += $size;
    }

    method !estimate-jump-size($mnemonic, $bit_mode) {
        if $bit_mode == 16 {
            if $mnemonic eq 'CALL' {
                return 3; # near call
            }
            return 2; # short jump
        }
        
        # 32bit/64bit モード
        if $mnemonic eq 'JMP' || $mnemonic eq 'CALL' {
            return 5; # rel32
        }
        return 6; # Jcc rel32 (0F 8x cd)
    }

    method !process-pseudo($node, %env) {
        my $mnemonic = $node.mnemonic;
        my @operands = $node.operands;

        given $mnemonic {
            when 'ORG'    { self!process-ORG($node, %env); }
            when 'DB'     { self!process-DB($node, %env); }
            when 'DW'     { self!process-DW($node, %env); }
            when 'DD'     { self!process-DD($node, %env); }
            when 'RESB'   { self!process-RESB($node, %env); }
            when 'ALIGNB' { self!process-ALIGNB($node, %env); }
            default {
                warn "Unknown pseudo-instruction: $mnemonic";
            }
        }
    }

    method !process-ORG($node, %env) {
        $!pc = self!eval-to-int($node.operands[0], %env);
    }

    method !process-DB($node, %env) {
        my $size = 0;
        for $node.operands -> $op {
            my $val = self!eval-to-any($op, %env);
            if $val ~~ Int {
                $size += 1;
            } elsif $val ~~ Str {
                $size += $val.chars;
            } elsif $val ~~ NumberExp {
                $size += 1;
            } else {
                # ラベルなどの識別子の場合（Pass1では1バイトと仮定するか、エラーにするか）
                # gosk ではラベルのアドレスの下位1バイトを格納するので 1 バイト
                $size += 1;
            }
        }
        $!pc += $size;
    }

    method !process-DW($node, %env) {
        my $size = 0;
        for $node.operands -> $op {
            $size += 2;
        }
        $!pc += $size;
    }

    method !process-DD($node, %env) {
        my $size = 0;
        for $node.operands -> $op {
            $size += 4;
        }
        $!pc += $size;
    }

    method !process-RESB($node, %env) {
        $!pc += self!eval-to-int($node.operands[0], %env);
    }

    method !process-ALIGNB($node, %env) {
        my $boundary = self!eval-to-int($node.operands[0], %env);
        if $boundary > 0 {
            my $padding = ($boundary - ($!pc % $boundary)) % $boundary;
            $!pc += $padding;
        }
    }

    method !size-of-instruction($node, %regs, %env) {
        my %info = $node.info;
        return 0 unless %info;

        given %info<type> {
            when 'no-op' { return 1; }
            when 'reg-imm8' { return 2; }
            when 'imm8' { return 2; }
            when 'imm16' { return 3; }
            when 'imm32' { return 5; }
            when 'short-jump' { return 2; }
        }
        # 未知の命令タイプや複雑なアドレッシングモードの場合は、
        # 将来的に ModR/M 計算ロジックを呼ぶ
        return 0;
    }

    method !eval-to-int($op, %env) {
        my $res = self!eval-to-any($op, %env);
        return $res if $res ~~ Int;
        return 0;
    }

    method !eval-to-any($op, %env) {
        if $op ~~ Immediate {
            my $res = $op.expr.eval(%env);
            if $res ~~ NumberExp {
                return $res.value;
            } else {
                return $op.expr.factor.eval(%env);
            }
        } elsif $op ~~ Expression {
            my $res = $op.eval(%env);
            if $res ~~ NumberExp {
                return $res.value;
            }
            return $res;
        } elsif $op ~~ Int | Str {
            return $op;
        }
        return 0;
    }
}
