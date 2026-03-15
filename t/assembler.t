use v6;
use Test;
use lib 'lib';
use Rakusk;

plan 5;

subtest "Basic Instructions" => {
    is-deeply assemble("CLI").binary.list, (0xFA,), "CLI (no-op)";
    is-deeply assemble("STI").binary.list, (0xFB,), "STI (no-op)";
    is-deeply assemble("NOP").binary.list, (0x90,), "NOP (no-op)";
    is-deeply assemble("PUSHA").binary.list, (0x60,), "PUSHA (no-op)";
}

subtest "MOV Instructions" => {
    is-deeply assemble("MOV AL, 0x12").binary.list, (0xB0, 0x12), "MOV AL, 0x12 (reg-imm8)";
    is-deeply assemble("MOV CL, 10").binary.list, (0xB1, 10), "MOV CL, 10 (decimal imm8)";
    is-deeply assemble("MOV AX, BX").binary.list, (0x89, 0xD8), "MOV AX, BX (reg-reg)";
    is-deeply assemble("MOV BX, AX").binary.list, (0x89, 0xC3), "MOV BX, AX (reg-reg)";
    is-deeply assemble("MOV SI, DI").binary.list, (0x89, 0xFE), "MOV SI, DI (reg-reg)";
}

subtest "32-bit Registers in 16-bit mode" => {
    is-deeply assemble("MOV EAX, EBX").binary.list, (0x66, 0x89, 0xD8), "MOV EAX, EBX (needs 66h)";
}

subtest "Multiple Lines" => {
    my $multi = "CLI\nSTI\nHLT";
    is-deeply assemble($multi).binary.list, (0xFA, 0xFB, 0xF4), "Multiple instructions";
}

subtest "Pseudo Instructions" => {
    my %cases = (
        "DB 0x55, 0xAA" => [0x55, 0xAA],
        "DB 'ABC'"      => [0x41, 0x42, 0x43],
        "DW 0x1234"     => [0x34, 0x12],
        "DD 0x12345678" => [0x78, 0x56, 0x34, 0x12],
        "RESB 4"        => [0x00, 0x00, 0x00, 0x00],
        "ORG 0x0\nDB 0x01\nALIGNB 4\nDB 0x02" => [0x01, 0x00, 0x00, 0x00, 0x02],
        "ORG 0x100\nDB \$" => [0x00], # Pass2では $ は 0x100 になるが DB $ (8bit) なので 0x00
        "ORG 0x1234\nDW \$" => [0x34, 0x12],
    );

    for %cases.kv -> $src, $expected {
        my $bin = assemble($src).binary;
        is-deeply $bin.list, $expected.List, "Case: $src";
    }
}

done-testing;