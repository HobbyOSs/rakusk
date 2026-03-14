use v6;
use Rakusk::AST;

unit role Rakusk::Pass1::Statement;

method process-statement($node, %regs, %env) {
    if $node ~~ LabelStmt {
        my $label = $node.label;
        $label ~~ s/\:$//;
        self.symbols{$label} = self.pc;
        return;
    }
    if $node ~~ DeclareStmt {
        my $val = self.eval-to-any($node.value, %env);
        self.symbols{$node.name} = $val;
        return;
    }

    if $node ~~ ConfigStmt {
        if $node.type eq 'BITS' {
            self.bit_mode = self.eval-to-int($node.value, %env);
        }
        return;
    }
}

method eval-to-int($op, %env) {
    my $res = self.eval-to-any($op, %env);
    return $res if $res ~~ Int;
    return 0;
}

method eval-to-any($op, %env) {
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