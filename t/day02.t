use v6;
use Test;
use Rakusk;
use lib 't';
use TestHelper;

plan 1;

# Day 02: port from gosk/test/day02_test.go
subtest "Hello OS 3 (Day 02)" => {
    my $asm = q:to/ASM/;
        ORG     0x7c00
        JMP     entry
        DB      0x90
        DB      "HELLOIPL"
        DW      512
        DB      1
        DW      1
        DB      2
        DW      224
        DW      2880
        DB      0xf0
        DW      9
        DW      18
        DW      2
        DD      0
        DD      2880
        DB      0, 0, 0x29
        DD      0xffffffff
        DB      "HELLO-OS   "
        DB      "FAT12   "
        RESB    18

entry:
        MOV     AX, 0
        MOV     SS, AX
        MOV     SP, 0x7c00
        MOV     DS, AX
        MOV     ES, AX

        MOV     SI, msg
putloop:
        MOV     AL, [SI]
        ADD     SI, 1
        CMP     AL, 0
        JE      fin
        MOV     AH, 0x0e
        MOV     BX, 15
        INT     0x10
        JMP     putloop
fin:
        HLT
        JMP     fin

msg:
        DB      0x0a, 0x0a
        DB      "hello, world"
        DB      0x0a
        DB      0

        RESB    0x7dfe-$

        DB      0x55, 0xaa

        DB      0xf0, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00
        RESB    4600
        DB      0xf0, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00
        RESB    1469432
ASM

    # Expected bytes from gosk/test/day02_test.go
    my $expected = Buf.new(
        0xeb, 0x4e,                                     # JMP entry
        0x90,                                           # DB 0x90
        0x48, 0x45, 0x4c, 0x4c, 0x4f, 0x49, 0x50, 0x4c, # "HELLOIPL"
        0x00, 0x02,                                     # DW 512
        0x01,                                           # DB 1
        0x01, 0x00,                                     # DW 1
        0x02,                                           # DB 2
        0xe0, 0x00,                                     # DW 224
        0x40, 0x0b,                                     # DW 2880
        0xf0,                                           # DB 0xf0
        0x09, 0x00,                                     # DW 9
        0x12, 0x00,                                     # DW 18
        0x02, 0x00,                                     # DW 2
        0x00, 0x00, 0x00, 0x00,                         # DD 0
        0x40, 0x0b, 0x00, 0x00,                         # DD 2880
        0x00, 0x00, 0x29,                               # DB 0,0,0x29
        0xff, 0xff, 0xff, 0xff,                         # DD 0xffffffff
        0x48, 0x45, 0x4c, 0x4c, 0x4f, 0x2d, 0x4f, 0x53, 0x20, 0x20, 0x20, # "HELLO-OS   "
        0x46, 0x41, 0x54, 0x31, 0x32, 0x20, 0x20, 0x20, # "FAT12   "
        (0x00 xx 18),                                   # RESB 18

        0xb8, 0x00, 0x00,                               # MOV AX, 0
        0x8e, 0xd0,                                     # MOV SS, AX
        0xbc, 0x00, 0x7c,                               # MOV SP, 0x7c00
        0x8e, 0xd8,                                     # MOV DS, AX
        0x8e, 0xc0,                                     # MOV ES, AX

        0xbe, 0x74, 0x7c,                               # MOV SI, msg
        # putloop:
        0x8a, 0x04,                                     # MOV AL, [SI]
        0x83, 0xc6, 0x01,                               # ADD SI, 1
        0x3c, 0x00,                                     # CMP AL, 0
        0x74, 0x09,                                     # JE fin
        0xb4, 0x0e,                                     # MOV AH, 0x0e
        0xbb, 0x0f, 0x00,                               # MOV BX, 15
        0xcd, 0x10,                                     # INT 0x10
        0xeb, 0xee,                                     # JMP putloop
        # fin:
        0xf4,                                           # HLT
        0xeb, 0xfd,                                     # JMP fin

        # msg:
        0x0a, 0x0a,                                     # DB 0x0a, 0x0a
        0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x2c, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, # "hello, world"
        0x0a,                                           # DB 0x0a
        0x00,                                           # DB 0

        (0x00 xx 378),                                  # RESB 0x7dfe-$

        0x55, 0xaa,                                     # DB 0x55, 0xaa

        0xf0, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, # DB 0xf0, ...
        (0x00 xx 4600),                                 # RESB 4600
        0xf0, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, # DB 0xf0, ...
        (0x00 xx 1469432)                               # RESB 1469432
    );

    my $actual = assemble($asm);
    is-binary($actual, $expected, "Hello OS 3 bootstrap sequence");
}

done-testing;
