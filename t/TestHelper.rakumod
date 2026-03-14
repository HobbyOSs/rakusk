unit module TestHelper;

use Test;

# 16進数文字列やDSLからBufを生成する
sub define-hex(@lines) is export {
    my $result = Buf.new;
    for @lines -> $line {
        my $clean-line = $line.subst(/'#' .*/, '').trim;
        next unless $clean-line;

        my @tokens = $clean-line.split(/\s+/, :skip-empty);
        next unless @tokens;

        my $cmd = @tokens.shift.uc;
        if $cmd eq 'DATA' {
            for @tokens -> $t is copy {
                $t.subst-mutate(/','+$/, ''); # カンマを除去
                if $t ~~ /^ '0x' (<[0..9a..fA..F]>+) $/ {
                    $result.push: :16($0.Str);
                } elsif $t ~~ /^ <[0..9a..fA..F]>**1..2 $/ { # 0xなしの16進数(1-2桁)を許容
                    $result.push: :16($t);
                } elsif $t ~~ /^ \d+ $/ {
                    $result.push: $t.Int;
                } elsif $t ~~ /^ \" (.*) \" $/ {
                    $result.append: $0.Str.encode('ascii');
                } else {
                    $result.append: $t.encode('ascii');
                }
            }
        } elsif $cmd eq 'FILL' {
            my $num = @tokens[0].Int;
            my $val = @tokens[1] // 0;
            if $val ~~ /^ '0x' (<[0..9a..fA..F]>+) $/ {
                $val = :16($0.Str);
            }
            $result.append: ($val.Int) xx $num;
        }
    }
    return $result;
}

# バイナリデータのhexdumpを生成する
sub hexdump(Buf $data, Int :$max-rows = 0) is export {
    my $dump = "";
    my $n = $data.elems;
    my $rows = 0;
    for 0, 16 ...^ $n -> $i {
        if $max-rows > 0 && $rows >= $max-rows {
            $dump ~= "... (truncated)\n";
            last;
        }
        my $row-count = ($n - $i) < 16 ?? ($n - $i) !! 16;
        my $bytes = $data.subbuf($i, $row-count);
        
        # Offset
        $dump ~= sprintf("%06x  ", $i);
        
        # Hex bytes
        for 0..15 -> $j {
            if $j < $row-count {
                $dump ~= sprintf("%02x ", $bytes[$j]);
            } else {
                $dump ~= "   ";
            }
        }
        
        # ASCII representation
        $dump ~= " '";
        for 0..$row-count-1 -> $j {
            my $c = $bytes[$j];
            $dump ~= (32 <= $c <= 126) ?? $c.chr !! ".";
        }
        $dump ~= "'\n";
        $rows++;
    }
    return $dump;
}

# 期待値と実際の値の差分（hexdump形式）を表示する
sub hex-diff(Buf $expected, Buf $actual, Int :$context = 3) is export {
    my $diff = "";
    my $n = $expected.elems < $actual.elems ?? $expected.elems !! $actual.elems;
    
    my $first-mismatch = -1;
    for 0..$n-1 -> $i {
        if $expected[$i] != $actual[$i] {
            $first-mismatch = $i;
            last;
        }
    }

    if $first-mismatch == -1 {
        if $expected.elems != $actual.elems {
            $first-mismatch = $n;
        } else {
            return "No difference found.";
        }
    }

    my $start-row = ($first-mismatch / 16).Int;
    my $start-offset = ($start-row - $context) * 16;
    $start-offset = 0 if $start-offset < 0;
    
    my $end-offset = ($start-row + $context + 1) * 16;
    
    $diff ~= "Mismatch at offset " ~ sprintf("0x%x", $first-mismatch) ~ "\n";
    $diff ~= "--- Expected (around offset) ---\n";
    $diff ~= hexdump-range($expected, $start-offset, $end-offset);
    $diff ~= "--- Actual (around offset) ---\n";
    $diff ~= hexdump-range($actual, $start-offset, $end-offset);
    
    return $diff;
}

sub hexdump-range(Buf $data, Int $start, Int $end) {
    my $len = $data.elems;
    my $actual-end = $end < $len ?? $end !! $len;
    my $actual-start = $start < $len ?? $start !! $len;
    
    my $res = "";
    for ($actual-start / 16).Int * 16, * + 16 ...^ $actual-end -> $i {
        my $row-count = ($len - $i) < 16 ?? ($len - $i) !! 16;
        my $bytes = $data.subbuf($i, $row-count);
        $res ~= sprintf("%06x  ", $i);
        for 0..15 -> $j {
            if $j < $row-count {
                $res ~= sprintf("%02x ", $bytes[$j]);
            } else {
                $res ~= "   ";
            }
        }
        $res ~= " '";
        for 0..$row-count-1 -> $j {
            my $c = $bytes[$j];
            $res ~= (32 <= $c <= 126) ?? $c.chr !! ".";
        }
        $res ~= "'\n";
    }
    return $res;
}

# バイナリ比較のためのカスタムテスト関数
sub is-binary(Buf $actual, Buf $expected, $desc) is export {
    if $actual eqv $expected {
        pass $desc;
    } else {
        flunk $desc;
        diag "Binary comparison failed.";
        if $actual.elems != $expected.elems {
            diag "Size mismatch: expected {$expected.elems}, got {$actual.elems}";
        }
        diag hex-diff($expected, $actual);
    }
}
