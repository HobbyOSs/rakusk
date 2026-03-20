use v6;
use Rakusk::AST;
use Rakusk::Pass2::Instruction;

unit role Rakusk::Pass1::Instruction does Rakusk::Pass2::Instruction;

method process-instruction($node, %regs, %env) {
    my $mnemonic = $node.mnemonic;
    
    # ジャンプ命令判定
    if $mnemonic ~~ /^ J | ^ CALL / {
        self.process-JMP($node, %regs, %env);
        return;
    }

    # それ以外の一般命令はエンコードを試みてサイズを確定させる
    my $size = self.size-of-instruction($node, %regs, %env);
    
    if $size == 0 {
        # エンコードに失敗した場合の安全なフォールバック
        my $type = $node.info<type> // '';
        if $type eq 'no-op' | 'reg' | 'sreg' {
            $size = 1;
        } else {
            $size = 2;
        }
    }
    $node.current_size = $size;
    self.pc += $size;
}

method size-of-instruction($node, %regs, %env) {
    # Pass 1 におけるサイズ計算。
    # エンコーディングロジックを流用する。
    # シンボル解決ができない場合を考慮し、一時的に symbols をクローンする。
    my %dummy_env = %env;
    %dummy_env<symbols> = %env<symbols>.clone;
    # 32ビットモード情報を正しく引き継ぐ
    %dummy_env<bit_mode> = self.bit_mode;
    
    my $bin = self.encode-instruction($node, %regs, %dummy_env);
    return $bin.elems;
}

method process-JMP($node, %regs, %env) {
    my $mnemonic = $node.mnemonic;
    my @operands = $node.operands;
    my %info = $node.info;

    # 既に確定しているサイズ（単調増加を維持）
    my $current_size = $node.current_size;

    my $type = %info<type> // '';

    # 1. 特殊なジャンプ形式（間接、FARなど）の優先処理
    if $type eq 'near-jump' {
        my $size = (self.bit_mode == 16 ?? 3 !! 5);
        $node.current_size = $size;
        self.pc += $size;
        return;
    }

    if $type eq 'mem-far' || $type eq 'mem-near' || $type eq 'reg-near' {
        my $size = self.size-of-instruction($node, %regs, %env);
        $node.current_size = $size;
        self.pc += $size;
        return;
    }

    my $size = 0;
    if @operands.elems > 0 {
        my $op = @operands[0];
        if $op ~~ SegmentedAddress {
            # JMP selector:offset
            my $use_32bit = (self.bit_mode == 32 || ($op.size_prefix // '') eq 'DWORD');
            if $use_32bit {
                $size = 7; # ptr16:32
                if self.bit_mode == 16 { $size += 1; }
            } else {
                $size = 5; # ptr16:16
            }
        } elsif $mnemonic eq 'CALL' && $op ~~ Immediate {
            # CALL rel16/rel32 (NEAR CALL)
            $size = (self.bit_mode == 16 ?? 3 !! 5);
        } elsif ($mnemonic eq 'JMP' || $mnemonic ~~ /^ J/) && $op ~~ Immediate {
            # JMP/Jcc rel8/rel16/rel32 (BDO対象)
            $size = self.calculate-jump-size($node, %regs, %env);
        } else {
            # それ以外の形式（レジスタ間接 JMP EAX など）
            $size = self.size-of-instruction($node, %regs, %env);
        }
    } else {
        $size = self.size-of-instruction($node, %regs, %env);
    }
    
    # 単調増加の保証
    if $size < $current_size {
        $size = $current_size;
    }
    
    $node.current_size = $size;
    self.pc += $size;
}

method calculate-jump-size($node, %regs, %env) {
    my $mnemonic = $node.mnemonic;
    my $target_op = $node.operands[0];
    
    # ターゲットアドレスの取得
    # シンボル未定義の場合は eval-to-int が 0 を返す可能性があるため、明示的に存在チェックを行う
    my $target_addr = self.eval-to-int($target_op, %env);
    
    if $target_op ~~ Immediate && $target_op.expr ~~ ImmExp {
        my $sym = $target_op.expr.factor.eval(%env);
        if $sym ~~ Str {
            unless %env<symbols>{$sym}:exists {
                # 2. 前方参照（TargetAddress が未確定）の場合、初回パス等では拡張をスキップし、2バイトを維持
                return 2;
            }
        }
    }

    # 3. 変位計算式を厳密に統一: Displacement = TargetAddress - (JumpInstAddress + 2)
    my $disp = $target_addr - (self.pc + 2);
    
    # 判定条件: -128 <= Displacement <= 127 の範囲内なら Short Jump
    if -128 <= $disp <= 127 {
        # nask compatible: 前方参照の場合は 127 バイト以内でも特定の条件下で NEAR を選ぶ場合がある。
        # 指示書には最短と仮定するようにあるので、一旦 2 を返す基本形に戻す。
        return 2;
    }

    # JCXZ / JECXZ は rel8 のみサポート
    if $mnemonic eq 'JCXZ' | 'JECXZ' {
        return 2;
    }

    # 4. 32ビットモードにおけるサイズ定数の再確認
    my $needed_size;
    if self.bit_mode == 32 {
        $needed_size = ($mnemonic eq 'JMP' ?? 5 !! 6); # JMP=5, Jcc=6
    } else {
        $needed_size = ($mnemonic eq 'JMP' ?? 3 !! 4); # JMP=3, Jcc=4
    }

    # デバッグ情報の強化
    if %*ENV<RAKUSK_DEBUG> && $needed_size > ($node.current_size // 2) {
        say "DEBUG: [BDO Expansion] mnemonic=$mnemonic PC={self.pc} target=$target_addr disp=$disp: size 2 -> $needed_size";
    }

    return $needed_size;
}

method estimate-jump-size($mnemonic, $bit_mode) {
    # 互換性のためのフォールバック
    if $mnemonic eq 'CALL' {
        return $bit_mode == 16 ?? 3 !! 5;
    }
    return 2;
}
