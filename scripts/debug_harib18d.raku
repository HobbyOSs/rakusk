use v6;
use lib 'lib';
use Rakusk::Grammar;

my $src = q:to/ASM/;
[FORMAT "WCOFF"]
[INSTRSET "i486p"]
[BITS 32]
[FILE "naskfunc.nas"]

		GLOBAL	_io_hlt
		EXTERN	_inthandler20

[SECTION .text]

_io_hlt:
		HLT
		RET

_asm_inthandler20:
		PUSH	ES
		PUSH	DS
		PUSHAD
		MOV		AX,SS
		CMP		AX,1*8
		JNE		.from_app
		RET
.from_app:
		MOV		EAX,1*8
		RET
ASM

my $lines = $src.lines;
for $lines.kv -> $i, $line {
    next if $line ~~ /^\s*$/;
    my $m = Assembler.parse($line ~ "\n", :rule('statement'));
    if $m {
        # say "Line { $i + 1 } OK: $line";
    } else {
        say "Line { $i + 1 } FAIL: $line";
        # 部分的に試す
        if $line ~~ /^\s* (.*)/ {
            my $content = ~$0;
            say "  Content: '$content'";
            my $m2 = Assembler.parse($content ~ "\n", :rule('statement'));
            say "  Statement with newline: " ~ ($m2 ?? "OK" !! "FAIL");
        }
    }
}