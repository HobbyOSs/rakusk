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
    my $size = self.size-of-instruction($node, %regs, %env);
    self.pc += $size;
}

method size-of-instruction($node, %regs, %env) {
    # 実際にエンコードしてサイズを測る
    # ただし、Pass 1 ではラベル未定義などで eval が失敗する可能性があるため、
    # eval-to-int をオーバーライドするか、env にダミーを入れる等の配慮が必要
    my $bin = self.encode-instruction($node, %regs, %env);
    return $bin.elems;
}

method process-JMP($node, %regs, %env) {
    my $mnemonic = $node.mnemonic;
    my @operands = $node.operands;
    my %info = $node.info;

    if (%info<type> // '') eq 'near-jump' {
        self.pc += (self.bit_mode == 16 ?? 3 !! 5);
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
    if $bit_mode == 16 {
        if $mnemonic eq 'CALL' {
            return 3;
        }
        return 2;
    }
    
    if $mnemonic eq 'JMP' || $mnemonic eq 'CALL' {
        return 5;
    }
    return 6;
}