use v6;
use Test;
use lib 'lib';
use Rakusk;

plan 7;

is-deeply assemble("CLI"), Buf.new(0xFA), "CLI (no-op)";
is-deeply assemble("STI"), Buf.new(0xFB), "STI (no-op)";
is-deeply assemble("NOP"), Buf.new(0x90), "NOP (no-op)";
is-deeply assemble("PUSHA"), Buf.new(0x60), "PUSHA (no-op)";
is-deeply assemble("MOV AL, 0x12"), Buf.new(0xB0, 0x12), "MOV AL, 0x12 (reg-imm8)";
is-deeply assemble("MOV CL, 10"), Buf.new(0xB1, 10), "MOV CL, 10 (decimal imm8)";

my $multi = "CLI\nSTI\nHLT";
is-deeply assemble($multi), Buf.new(0xFA, 0xFB, 0xF4), "Multiple instructions";

done-testing;