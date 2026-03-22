use v6;
use Test;
use lib 'lib';
use Rakusk;

plan 2;

subtest "FNSAVE [EAX]" => {
    my $asm = q:to/ASM/;
        [BITS 32]
        FNSAVE [EAX]
    ASM
    # FNSAVE [EAX] (opcode DD, extension 6)
    # ModR/M: mod=00, reg=110 (6), rm=000 (EAX) -> 0x30
    is-deeply assemble($asm).binary.list, (0xDD, 0x30), "FNSAVE [EAX] should be DD 30";
}

subtest "FRSTOR [EAX]" => {
    my $asm = q:to/ASM/;
        [BITS 32]
        FRSTOR [EAX]
    ASM
    # FRSTOR [EAX] (opcode DD, extension 4)
    # ModR/M: mod=00, reg=100 (4), rm=000 (EAX) -> 0x20
    is-deeply assemble($asm).binary.list, (0xDD, 0x20), "FRSTOR [EAX] should be DD 20";
}

done-testing;