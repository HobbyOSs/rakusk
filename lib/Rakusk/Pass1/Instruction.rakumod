use v6;
use Rakusk::AST;
use Rakusk::Pass2::Instruction;

unit role Rakusk::Pass1::Instruction does Rakusk::Pass2::Instruction;

method process-instruction($node, %regs, %env) {
    my $mnemonic = $node.mnemonic;
    
    # ジャンプ命令判定（これらは推定が必要な場合があるため個別処理を残す）
    if $mnemonic ~~ /^ J | ^ CALL / {
        self.process-JMP($node, %regs, %env);
        return;
    }

    # それ以外の一般命令はエンコードを試みてサイズを確定させる
    # Pass 1 の段階で bit_mode が正しく設定されていることを前提にする
    my $size = self.size-of-instruction($node, %regs, %env);
    
    if $size == 0 {
        # エンコードに失敗した場合（未定義の命令タイプ等）、安全なフォールバック
        if ($node.info<type> // '') eq 'no-op' {
            $size = 1;
        } else {
            # type が reg, sreg などの1バイト命令である可能性を考慮
            my $type = $node.info<type> // '';
            if $type eq 'reg' || $type eq 'sreg' {
                $size = 1;
            } else {
                $size = 2;
            }
        }
    }
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

    my $type = %info<type> // '';
    if $type eq 'near-jump' {
        self.pc += (self.bit_mode == 16 ?? 3 !! 5);
        return;
    }

    if $type eq 'mem-far' {
        # 間接FARジャンプ/コール。通常の命令と同様にサイズ計算が可能。
        self.pc += self.size-of-instruction($node, %regs, %env);
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
                if self.bit_mode == 16 {
                    $size += 1; # 66h prefix
                }
            } else {
                $size = 5; # ptr16:16
            }
        } else {
            # 短い形式(short/near)の選択はパス1の段階では難しい場合があるため、
            # 現状は安全なサイズを推定する
            $size = self.estimate-jump-size($mnemonic, self.bit_mode);
        }
    } else {
        $size = self.estimate-jump-size($mnemonic, self.bit_mode);
    }
    
    self.pc += $size;
}

method estimate-jump-size($mnemonic, $bit_mode) {
    # 32bit mode でも条件分岐はまず 2 byte (short jump) と仮定してみる
    # これによりラベル位置が nask と一致しやすくなる
    if $mnemonic eq 'CALL' {
        return $bit_mode == 16 ?? 3 !! 5;
    }
    return 2;
}
