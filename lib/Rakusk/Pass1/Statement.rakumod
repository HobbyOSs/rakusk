use v6;
use Rakusk::AST;
use Rakusk::Util;

unit role Rakusk::Pass1::Statement does Evaluator;

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
        } elsif $node.type eq 'FORMAT' {
            self.output_format = self.eval-to-str($node.value, %env);
        } elsif $node.type eq 'FILE' {
            self.source_file_name = self.eval-to-str($node.value, %env);
        } elsif $node.type eq 'SECTION' {
            self.current_section = self.eval-to-str($node.value, %env);
            self.sections.push(self.current_section) unless self.current_section (elem) self.sections;
        }
        return;
    }
}
