use v6;
use Rakusk::AST;

unit role Rakusk::Pass2::Pseudo;

method encode-pseudo($node, %env) {
    my $bin = Buf.new();
    my $current_pc = %env<PC> // 0;

    given $node.mnemonic {
        when 'DB' {
            for $node.operands -> $op {
                my $val = self.eval-to-any($op, %env);
                if $val ~~ Int {
                    $bin.push($val % 256);
                } elsif $val ~~ Str {
                    if $val.chars > 1 {
                        $bin ~= $val.encode('ascii');
                    } else {
                        $bin.push($val.ord % 256);
                    }
                }
            }
        }
        when 'DW' {
            for $node.operands -> $op {
                my $val = self.eval-to-int($op, %env);
                $bin.push($val % 256);
                $bin.push(($val +> 8) % 256);
            }
        }
        when 'DD' {
            for $node.operands -> $op {
                my $val = self.eval-to-int($op, %env);
                $bin.push($val % 256);
                $bin.push(($val +> 8) % 256);
                $bin.push(($val +> 16) % 256);
                $bin.push(($val +> 24) % 256);
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