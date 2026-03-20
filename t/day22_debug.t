use v6;
use Test;
use Rakusk;
use lib 't';
use TestHelper;

subtest "32-bit instructions and addressing" => {
    # BITS 32 モードでの検証
    # nask (ndisasm) での期待値:
    # IRETD: CF
    # PUSHFD: 9C
    # POPFD: 9D
    # JMP FAR [ESP+4]: FF 6C 24 04
    # MOV EAX, [ESP+4]: 8B 44 24 04
    
    my $asm = q:to/ASM/;
[BITS 32]
        IRETD           ; Expected: CF
        PUSHFD          ; Expected: 9C
        POPFD           ; Expected: 9D
        JMP FAR [ESP+4] ; Expected: FF 6C 24 04
        MOV EAX, [ESP+4]; Expected: 8B 44 24 04
ASM

    my $expected = Buf.new(
        0xCF,
        0x9C,
        0x9D,
        0xFF, 0x6C, 0x24, 0x04,
        0x8B, 0x44, 0x24, 0x04
    );

    my $res = assemble($asm);
    is-binary($res.binary, $expected, "32-bit instructions match");
}

done-testing;