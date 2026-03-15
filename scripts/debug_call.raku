use v6;
use lib 'lib';
use Rakusk::Grammar;

sub test-parse($token, $text) {
    say "--- Testing $token with '$text' ---";
    my $m = Assembler.parse($text, :rule($token));
    if $m {
        say "OK: «{$m.Str}»";
        if $m.can('made') {
            try {
                my $made = $m.made;
                say "Made: " ~ $made.raku;
            }
        }
    } else {
        say "FAIL";
    }
}

my $actions = AssemblerActions.new;
my $src = "		CALL	_inthandler20\n";
say "Testing TOP with CALL...";
my $m = Assembler.parse($src, :$actions);
if $m {
    say "TOP OK";
    for $m.made -> $node {
        say "Node: " ~ $node.raku;
    }
} else {
    say "TOP FAIL";
    # Try individual rules
    test-parse('mnemonic_stmt', "CALL	_inthandler20");
    test-parse('operand_list', "_inthandler20");
    test-parse('operand', "_inthandler20");
    test-parse('exp', "_inthandler20");
}