use v6;
unit module Rakusk::Pass1;
use Rakusk::AST;

class Pass1 is export {
    has %.symbols;
    has @.ast;
    has Int $.pc = 0;
    has Int $.bit_mode = 16;
    has @.global_symbols;
    has @.extern_symbols;

    method evaluate(@ast, %regs) {
        @!ast = @ast;
        
        # パス1: ラベル・定数の収集とPCの計算
        $!pc = 0;
        $!bit_mode = 16;
        @!global_symbols = [];
        @!extern_symbols = [];

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
        
        # ジャンプ命令判定
        if $mnemonic ~~ /^ J | ^ CALL / {
            self!process-JMP($node, %regs, %env);
            return;
        }

        # ハンドラ振り分け
        given $mnemonic {
            when 'MOV' { self!process-MOV($node, %regs, %env); }
            when 'RET' { self!process-RET($node, %regs, %env); }
            when 'INT' { self!process-INT($node, %regs, %env); }
            when 'IN'  { self!process-IN($node, %regs, %env); }
            when 'OUT' { self!process-OUT($node, %regs, %env); }
            when 'LGDT' { self!process-LGDT($node, %regs, %env); }
            # 算術・論理演算命令
            when 'ADD' | 'ADC' | 'SUB' | 'SBB' | 'CMP' | 'INC' | 'DEC' | 'NEG' | 'MUL' | 'IMUL' | 'DIV' | 'IDIV' |
                 'AND' | 'OR' | 'XOR' | 'NOT' | 'SHR' | 'SHL' | 'SAR' {
                self!process-arith-logic($node, %regs, %env);
            }
            # PUSH/POP
            when 'PUSH' | 'POP' {
                self!process-push-pop($node, %regs, %env);
            }
            default {
                # パラメータなし命令またはデフォルト処理
                self!process-generic-inst($node, %regs, %env);
            }
        }
    }

    method !process-MOV($node, %regs, %env) {
        my $size = self!size-of-instruction($node, %regs, %env);
        $!pc += $size;
    }

    method !process-INT($node, %regs, %env) {
        my $size = 2; # INT imm8
        if $node.operands.elems > 0 {
            my $val = self!eval-to-any($node.operands[0], %env);
            if $val == 3 {
                $size = 1; # INT 3 (CC)
            }
        }
        $!pc += $size;
    }

    method !process-IN($node, %regs, %env) {
        my $size = self!size-of-instruction($node, %regs, %env);
        $!pc += $size;
    }

    method !process-OUT($node, %regs, %env) {
        my $size = self!size-of-instruction($node, %regs, %env);
        $!pc += $size;
    }

    method !process-LGDT($node, %regs, %env) {
        # LGDT m16:32 (0F 01 /2)
        # とりあえず 5~7 バイト程度を想定 (goskでは dispサイズに依存)
        my $size = 5; 
        $!pc += $size;
    }

    method !process-arith-logic($node, %regs, %env) {
        my $size = self!size-of-instruction($node, %regs, %env);
        $!pc += $size;
    }

    method !process-push-pop($node, %regs, %env) {
        my $size = self!size-of-instruction($node, %regs, %env);
        $!pc += $size;
    }

    method !process-generic-inst($node, %regs, %env) {
        my $mnemonic = $node.mnemonic;
        my $size = 1;

        # gosk の processNoParam にある例外対応
        given $mnemonic {
            when 'IRETQ' | 'SYSENTER' | 'SYSEXIT' | 'SYSCALL' | 'SYSRET' | 'UD2' {
                $size = 2;
            }
            when /^F/ {
                # x87 命令の多くは 2バイト
                $size = 2;
            }
            default {
                # JSON定義から取得を試みる
                my $info_size = self!size-of-instruction($node, %regs, %env);
                $size = $info_size if $info_size > 0;
            }
        }
        $!pc += $size;
    }

    method !process-RET($node, %regs, %env) {
        # RET (C3) は 1バイト
        # RET imm16 (C2 iw) は 3バイト
        my $size = 1;
        if $node.operands.elems > 0 {
            $size = 3;
        }
        $!pc += $size;
    }

    method !process-JMP($node, %regs, %env) {
        my $mnemonic = $node.mnemonic;
        my @operands = $node.operands;

        # オペランドが評価可能かチェック
        if @operands.elems > 0 {
            my $op = @operands[0];
            # TODO: SegmentedAddress (FAR jump) の判定
            # 現時点では AST に SegmentedAddress が未定義のため一旦コメントアウト
            # if $op ~~ SegmentedAddress {
            #     # FAR Jump/Call
            #     # 16-bit: 66 EA ptr16:16 or EA ptr16:16
            #     # 32-bit: EA ptr16:32
            #     if $!bit_mode == 16 {
            #         $!pc += 5; # EA ptr16:16
            #     } else {
            #         $!pc += 7; # EA ptr16:32
            #     }
            #     return;
            # }
        }

        my $size = self!estimate-jump-size($mnemonic, $!bit_mode);
        $!pc += $size;
    }

    method !estimate-jump-size($mnemonic, $bit_mode) {
        if $bit_mode == 16 {
            if $mnemonic eq 'CALL' {
                return 3; # near call (E8 cw)
            }
            # JMP/Jcc short を推定
            return 2; # short jump (EB rb / 7x rb)
        }
        
        # 32bit/64bit モード
        if $mnemonic eq 'JMP' || $mnemonic eq 'CALL' {
            return 5; # near rel32 (E9/E8 cd)
        }
        # Jcc near (0F 8x cd)
        return 6;
    }

    method !process-pseudo($node, %env) {
        my $mnemonic = $node.mnemonic;

        given $mnemonic {
            when 'ORG'    { self!process-ORG($node, %env); }
            when 'DB'     { self!process-DB($node, %env); }
            when 'DW'     { self!process-DW($node, %env); }
            when 'DD'     { self!process-DD($node, %env); }
            when 'RESB'   { self!process-RESB($node, %env); }
            when 'ALIGNB' { self!process-ALIGNB($node, %env); }
            when 'GLOBAL' { self!process-GLOBAL($node, %env); }
            when 'EXTERN' { self!process-EXTERN($node, %env); }
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
                $size += $val.encode('UTF-8').elems;
            } elsif $val ~~ NumberExp {
                $size += 1;
            } else {
                # ラベルなどの識別子の場合、gosk準拠で下位1バイトとする
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

    method !process-GLOBAL($node, %env) {
        for $node.operands -> $op {
            # オペランドは識別子であることを期待
            if $op ~~ Immediate && $op.expr.factor ~~ IdentFactor {
                my $name = $op.expr.factor.value;
                @!global_symbols.push($name) unless $name leg any(@!global_symbols);
            }
        }
    }

    method !process-EXTERN($node, %env) {
        for $node.operands -> $op {
            if $op ~~ Immediate && $op.expr.factor ~~ IdentFactor {
                my $name = $op.expr.factor.value;
                @!extern_symbols.push($name) unless $name leg any(@!extern_symbols);
            }
        }
    }

    method !size-of-instruction($node, %regs, %env) {
        my %info = $node.info;
        return 0 unless %info;

        given %info<type> {
            when 'no-op' { return 1; }
            when 'reg-imm8' {
                # reg8, imm8 -> 2 bytes (B0+r ib) or (80 /0 ib)
                # reg16, imm8 -> 3 bytes (83 /0 ib)
                return (%info<width> // 8) == 8 ?? 2 !! 3;
            }
            when 'short-imm' {
                # opcode + imm8 (2 bytes) or opcode + imm16 (3 bytes)
                return (%info<width> // 8) == 8 ?? 2 !! 3;
            }
            when 'reg-imm16' { return 3; }
            when 'imm8' { return 2; }
            when 'imm16' { return 3; }
            when 'imm32' { return 5; }
            when 'short-jump' { return 2; }
            when 'reg-reg' { return 2; }
            when 'sreg-reg' | 'reg-sreg' { return 2; }
            when 'reg-mem' | 'mem-reg' {
                # 16-bit mode: opcode (1) + ModR/M (1) + displacement (0, 1, 2)
                my $size = 2;
                my $mem = $node.operands.grep(Memory)[0];
                if $mem && $mem.disp {
                    my $dv = self!eval-to-int($mem.disp, %env);
                    if $dv != 0 {
                        $size += ($dv.abs <= 127 ?? 1 !! 2);
                    }
                }
                return $size;
            }
        }
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