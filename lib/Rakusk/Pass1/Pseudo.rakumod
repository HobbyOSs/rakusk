use v6;
use Rakusk::AST;

unit role Rakusk::Pass1::Pseudo;

method process-pseudo($node, %env) {
    my $mnemonic = $node.mnemonic;

    given $mnemonic {
        when 'ORG'    { self.process-ORG($node, %env); }
        when 'DB'     { self.process-DB($node, %env); }
        when 'DW'     { self.process-DW($node, %env); }
        when 'DD'     { self.process-DD($node, %env); }
        when 'RESB'   { self.process-RESB($node, %env); }
        when 'ALIGNB' { self.process-ALIGNB($node, %env); }
        when 'GLOBAL' { self.process-GLOBAL($node, %env); }
        when 'EXTERN' { self.process-EXTERN($node, %env); }
        default {
            warn "Unknown pseudo-instruction: $mnemonic";
        }
    }
}

method process-ORG($node, %env) {
    self.pc = self.eval-to-int($node.operands[0], %env);
}

method process-DB($node, %env) {
    my $size = 0;
    for $node.operands -> $op {
        my $val = self.eval-to-any($op, %env);
        if $val ~~ Int {
            $size += 1;
        } elsif $val ~~ Str {
            $size += $val.encode('UTF-8').elems;
        } elsif $val ~~ NumberExp {
            $size += 1;
        } else {
            $size += 1;
        }
    }
    self.pc += $size;
}

method process-DW($node, %env) {
    my $size = 0;
    for $node.operands -> $op {
        $size += 2;
    }
    self.pc += $size;
}

method process-DD($node, %env) {
    my $size = 0;
    for $node.operands -> $op {
        $size += 4;
    }
    self.pc += $size;
}

method process-RESB($node, %env) {
    self.pc += self.eval-to-int($node.operands[0], %env);
}

method process-ALIGNB($node, %env) {
    my $boundary = self.eval-to-int($node.operands[0], %env);
    if $boundary > 0 {
        my $padding = ($boundary - (self.pc % $boundary)) % $boundary;
        self.pc += $padding;
    }
}

method process-GLOBAL($node, %env) {
    for $node.operands -> $op {
        if $op ~~ Immediate && $op.expr.factor ~~ IdentFactor {
            my $name = $op.expr.factor.value;
            self.global_symbols.push($name) unless $name leg any(self.global_symbols);
        }
    }
}

method process-EXTERN($node, %env) {
    for $node.operands -> $op {
        if $op ~~ Immediate && $op.expr.factor ~~ IdentFactor {
            my $name = $op.expr.factor.value;
            self.extern_symbols.push($name) unless $name leg any(self.extern_symbols);
        }
    }
}