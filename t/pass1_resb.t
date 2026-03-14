use v6;
use Test;
use Rakusk::AST;
use Rakusk::Pass1;
use Rakusk::Grammar;

plan 1;

sub parse-and-pass1($source) {
    my $actions = AssemblerActions.new();
    my $match = Assembler.parse($source, :$actions);
    die "Parse failed for: $source" unless $match;
    my @ast = $match.made;
    my $pass1 = Pass1.new().evaluate(@ast, {});
    return $pass1;
}

subtest 'RESB with $ evaluation', {
    my $source = q:to/END/;
        ORG 0x7c00
        RESB 0x7dfe-$
    END
    my $p1 = parse-and-pass1($source);
    # 0x7c00 から開始し、 0x7dfe - 0x7c00 = 510 バイト予約されるので
    # 最終的な PC は 0x7dfe になるはず
    is $p1.pc, 0x7dfe, 'RESB 0x7dfe-$ should advance PC to 0x7dfe (starts from 0x7c00)';
}

done-testing;