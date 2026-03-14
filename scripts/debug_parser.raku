use v6;
use lib 'lib';
use Rakusk::Grammar;

sub test-parse($token, $text) {
    print "Testing $token with '$text': ";
    my $m = Assembler.parse($text, :rule($token));
    if $m {
        say "OK";
    } else {
        say "FAIL";
    }
}

say "--- Testing Factors ---";
test-parse('num_lit', "30");
test-parse('num_lit', "-30");
test-parse('hex_lit', "0x0ff0");
test-parse('ident', "_testZ009");
test-parse('factor', "30");
test-parse('factor', "0x0ff0");

say "\n--- Testing Expressions ---";
test-parse('exp', "10");
test-parse('exp', "CYLS");
test-parse('exp', "512*18*2/4");

say "\n--- Testing Statements ---";
test-parse('label_stmt', "entry:");
test-parse('opcode_stmt', "HLT");
test-parse('mnemonic_stmt', "MOV AL, 0x12");
test-parse('statement', "CLI\n");

say "\n--- Testing TOP ---";
my $src = "CLI\nSTI\nHLT";
my $m = Assembler.parse($src, :actions(AssemblerActions.new));
if $m {
    say "TOP OK";
    my @ast = $m.made;
    say "Number of statements: " ~ @ast.elems;
    for @ast -> $stmt {
        say " - " ~ $stmt.mnemonic;
    }
} else {
    say "TOP FAIL";
}
