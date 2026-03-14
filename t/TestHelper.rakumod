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
            for @tokens -> $t {
                if $t ~~ /^ '0x' (<[0..9a..fA..F]>+) $/ {
                    $result.push: :16($0.Str);
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
sub hexdump(Buf $data) is export {
    my $dump = "";
    my $n = $data.elems;
    for 0, 16 ...^ $n -> $i {
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
    }
    return $dump;
}

# 期待値と実際の値の差分（hexdump形式）を表示する
sub hex-diff(Buf $expected, Buf $actual) is export {
    my $res = "--- Expected ---\n" ~ hexdump($expected);
    $res   ~= "--- Actual   ---\n" ~ hexdump($actual);
    return $res;
}