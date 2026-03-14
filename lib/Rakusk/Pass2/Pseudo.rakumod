use v6;
use Rakusk::AST;
use Rakusk::Util;

unit role Rakusk::Pass2::Pseudo;

method encode-pseudo($node, %env) {
    my $bin = Buf.new();
    my $current_pc = %env<PC> // 0;

    given $node.mnemonic {
        when 'DB' {
            for $node.operands -> $op {
                my $val = self.eval-to-any($op, %env);
                if $val ~~ Int {
                    $bin ~= pack-le($val, 8);
                } elsif $val ~~ Str {
                    $bin ~= pack-str($val);
                }
            }
        }
        when 'DW' {
            for $node.operands -> $op {
                my $val = self.eval-to-int($op, %env);
                $bin ~= pack-le($val, 16);
            }
        }
        when 'DD' {
            for $node.operands -> $op {
                my $val = self.eval-to-int($op, %env);
                $bin ~= pack-le($val, 32);
            }
        }
        when 'RESB' {
            my $size = self.eval-to-int($node.operands[0], %env);
            $bin.push(0) for 1..$size;
        }
        when 'ALIGNB' {
            my $boundary = self.eval-to-int($node.operands[0], %env);
            my $padding = ($boundary - ($current_pc % $boundary)) % $boundary;
            $bin.push(0) for 1..$padding;
        }
    }
    return $bin;
}