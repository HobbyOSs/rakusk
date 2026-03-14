use v6;
use Test;
use Rakusk::Grammar;

plan *;

my @test-cases = (
    # Basic instructions
    { input => "MOV AX, BX", desc => "basic mov" },
    { input => "DB 0x90", desc => "DB directive" },
    { input => "HLT", desc => "no-operand instruction" },

    # Immediates
    { input => "MOV AL, 123", desc => "decimal immediate" },
    { input => "MOV AL, 0xFF", desc => "hex immediate" },

    # Labels and symbols
    { input => "entry:", desc => "label definition" },
    { input => "msg: DB \"hello\"", desc => "label and instruction" },

    # Variable declaration (EQU)
    { input => "BOTPAK EQU 0x00280000", desc => "EQU declaration" },

    # Config declaration
    { input => "[FORMAT \"WCOFF\"]", desc => "config declaration" },
    { input => "[BITS 16]", desc => "bits config" },

    # Comments and whitespace
    { input => "  MOV AX, BX  ", desc => "leading/trailing whitespace" },
    { input => "MOV AX, BX ; comment", desc => "semicolon comment" },
    { input => "MOV AX, BX # comment", desc => "hash comment" },
    { input => "# full line comment", desc => "full line comment" },
    { input => "", desc => "empty line" },
);

for @test-cases -> %tc {
    ok Assembler.parse(%tc<input>), %tc<desc> // %tc<input>;
}

done-testing;