use v6;
use Test;
use Rakusk;
use lib 't';
use TestHelper;

# plan :skip-all("Failing with binary mismatch at offset 0x24");

subtest "Harib00h (Day 03)" => {
    my $asm = q:to/ASM/;
CYLS    EQU     0x0ff0
LEDS    EQU     0x0ff1
VMODE   EQU     0x0ff2
SCRNX   EQU     0x0ff4
SCRNY   EQU     0x0ff6
VRAM    EQU     0x0ff8

        ORG     0xc200

        MOV     AL, 0x13
        MOV     AH, 0x00
        INT     0x10
        MOV     BYTE [VMODE], 8
        MOV     WORD [SCRNX], 320
        MOV     WORD [SCRNY], 200
        MOV     DWORD [VRAM], 0x000a0000

        MOV     AH, 0x02
        INT     0x16
        MOV     [LEDS], AL

fin:
        HLT
        JMP     fin
ASM

    my $expected = Buf.new(
        0xb0, 0x13,
        0xb4, 0x00,
        0xcd, 0x10,
        0xc6, 0x06, 0xf2, 0x0f, 0x08,
        0xc7, 0x06, 0xf4, 0x0f, 0x40, 0x01,
        0xc7, 0x06, 0xf6, 0x0f, 0xc8, 0x00,
        0x66, 0xc7, 0x06, 0xf8, 0x0f, 0x00, 0x00, 0x0a, 0x00,
        0xb4, 0x02,
        0xcd, 0x16,
        0xa2, 0xf1, 0x0f,
        0xf4,
        0xeb, 0xfd
    );

    my $actual = assemble($asm);
    is-binary($actual, $expected, "Harib00h sequence");
}

done-testing;