use v6;
use Test;
use Rakusk::Grammar;

plan :skip-all("Grammar not yet supporting dot-started labels correctly");

subtest "dot-started labels" => {
    my @test-cases = (
        { input => ".from_app:", desc => "dot-started label definition" },
        { input => "JNE .from_app", desc => "jump to dot-started label" },
        { input => "_asm_inthandler20:", desc => "underscore label" },
        { input => "GLOBAL _io_hlt", desc => "GLOBAL with underscore" },
    );

    for @test-cases -> %tc {
        ok Assembler.parse(%tc<input> ~ "\n", :rule('statement')), %tc<desc>;
    }
}

subtest "config statements with spaces" => {
    my @test-cases = (
        { input => "[SECTION .text]", desc => "SECTION with dot" },
        { input => "[BITS 32]", desc => "standard BITS" },
        { input => "[FORMAT \"WCOFF\"]", desc => "standard FORMAT" },
    );

    for @test-cases -> %tc {
        ok Assembler.parse(%tc<input> ~ "\n", :rule('statement')), %tc<desc>;
    }
}

subtest "complex factor combinations" => {
    my @test-cases = (
        { input => "MOV EAX, 1*8", desc => "multiplication in immediate" },
        { input => "MOV AX, SS", desc => "segment register" },
        { input => "MOV ECX, [0xfe4]", desc => "memory access" },
    );

    for @test-cases -> %tc {
        ok Assembler.parse(%tc<input> ~ "\n", :rule('statement')), %tc<desc>;
    }
}

subtest "labels inside instructions" => {
    my $src = ".from_app:\n\tMOV EAX, 1*8\n";
    ok Assembler.parse($src), "parsing source with dot label";
}

done-testing;
