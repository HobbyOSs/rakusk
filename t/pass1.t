use v6;
use Test;
use Rakusk::AST;
use Rakusk::Pass1;
use Rakusk::Grammar;

plan 8;

sub parse-and-pass1($source) {
    my $actions = AssemblerActions.new();
    my $match = Assembler.parse($source, :$actions);
    die "Parse failed for: $source" unless $match;
    my @ast = $match.made;
    my $pass1 = Pass1.new().evaluate(@ast, {});
    return $pass1;
}

subtest "config/BITS", {
    my $p1 = parse-and-pass1("[BITS 32]");
    is $p1.pc, 0, "Initial PC is 0";
    # TODO: bit-mode のチェックが必要なら Pass1 にプロパティを追加する
}

subtest "EQU (DeclareStmt)", {
    my $p1 = parse-and-pass1("CYLS EQU 10");
    is $p1.symbols<CYLS>, 10, "CYLS is 10";
}

subtest "DB size calculation", {
    my $p1 = parse-and-pass1("DB 0x90");
    is $p1.pc, 1, "DB 0x90 size is 1";

    $p1 = parse-and-pass1('DB "HELLO-OS   "');
    is $p1.pc, 11, 'DB "HELLO-OS   " size is 11';
}

subtest "ORG", {
    my $p1 = parse-and-pass1("ORG 0x7c00");
    is $p1.pc, 0x7c00, "PC is 0x7c00 after ORG";
}

subtest "RESB", {
    my $p1 = parse-and-pass1("RESB 18");
    is $p1.pc, 18, "RESB 18 advances PC by 18";

    $p1 = parse-and-pass1("ORG 0x7c00\nRESB 0x7dfe-\$");
    # 0x7c00 から 0x7dfe までの差分
    is $p1.pc, 0x7dfe, "RESB with \$ calculation: PC reached 0x7dfe";
}

subtest "Labels", {
    my $p1 = parse-and-pass1("ORG 0x7c00\nlabel:\nHLT");
    is $p1.symbols<label>, 0x7c00, "label is at 0x7c00";
    is $p1.pc, 0x7c01, "PC advances after HLT";
}

subtest "Integration (Brief)", {
    my $source = q:to/END/;
        ORG 0x7c00
        entry:
            DB 0x90
            DB "HELLOIPL"
            RESB 10
        END
    my $p1 = parse-and-pass1($source);
    is $p1.symbols<entry>, 0x7c00, "entry at 0x7c00";
    # 0x7c00 + 1 (0x90) + 8 ("HELLOIPL") + 10 = 0x7c00 + 19 = 0x7c13
    is $p1.pc, 0x7c13, "PC advances correctly";
}

subtest "Complex labels and PC", {
    my $source = q:to/END/;
        ORG 0x7c00
        start:
            HLT
        middle:
            DB 0x90
        finish:
        END
    my $p1 = parse-and-pass1($source);
    is $p1.symbols<start>,  0x7c00, "start at 0x7c00";
    is $p1.symbols<middle>, 0x7c01, "middle at 0x7c01";
    is $p1.symbols<finish>, 0x7c02, "finish at 0x7c02";
}

done-testing;