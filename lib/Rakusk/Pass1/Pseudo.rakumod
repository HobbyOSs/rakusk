use v6;
use Rakusk::AST;
use Rakusk::Pass2::Pseudo;

unit role Rakusk::Pass1::Pseudo does Rakusk::Pass2::Pseudo;

method process-pseudo($node, %env) {
    my $mnemonic = $node.mnemonic;

    given $mnemonic {
        when 'ORG'    { self.process-ORG($node, %env); }
        when 'GLOBAL' { self.process-GLOBAL($node, %env); }
        when 'EXTERN' { self.process-EXTERN($node, %env); }
        default {
            # DB, DW, DD, RESB, ALIGNBなどは実際にエンコードしてサイズを測る
            my $bin = self.encode-pseudo($node, %env);
            if $bin.elems > 0 || $mnemonic eq 'RESB' | 'ALIGNB' | 'DB' | 'DW' | 'DD' {
                self.pc += $bin.elems;
            } else {
                warn "Unknown pseudo-instruction: $mnemonic";
            }
        }
    }
}

method process-ORG($node, %env) {
    self.pc = self.eval-to-int($node.operands[0], %env);
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