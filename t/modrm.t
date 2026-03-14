use v6;
use Test;
use Rakusk::Util;

plan 4;

subtest "Basic pack-modrm tests" => {
    # [ Mod (2bit) | Reg (3bit) | R/M (3bit) ]
    # MOV EAX, EBX -> Mod=3 (11), Reg=EBX=3 (011), RM=EAX=0 (000)
    # Binary: 11 011 000 = 0xD8 (decimal 216)
    is pack-modrm(mod => 3, reg => 3, rm => 0), 0xD8, "MOV EAX, EBX (Mod=3, Reg=3, RM=0) is 0xD8";

    # MOV EBX, EAX -> Mod=3 (11), Reg=EAX=0 (000), RM=EBX=3 (011)
    # Binary: 11 000 011 = 0xC3 (decimal 195)
    is pack-modrm(mod => 3, reg => 0, rm => 3), 0xC3, "MOV EBX, EAX (Mod=3, Reg=0, RM=3) is 0xC3";
};

subtest "Random property tests (Simple implementation)" => {
    for 1..100 {
        my $mod = (0..3).pick;
        my $reg = (0..7).pick;
        my $rm  = (0..7).pick;
        
        my $expected = ($mod +< 6) +| ($reg +< 3) +| $rm;
        my $actual = pack-modrm(mod => $mod, reg => $reg, rm => $rm);
        
        if $actual != $expected {
            flunk "Failed for Mod=$mod, Reg=$reg, RM=$rm";
            return;
        }
    }
    pass "100 random combinations passed";
};

subtest "Register mapping verification" => {
    my %regs = (
        "EAX" => 0, "ECX" => 1, "EDX" => 2, "EBX" => 3,
        "ESP" => 4, "EBP" => 5, "ESI" => 6, "EDI" => 7
    );
    
    # Example: MOV ESI, EDI -> Mod=3, Reg=EDI(7), RM=ESI(6)
    # 11 111 110 = 0xFE
    is pack-modrm(mod => 3, reg => %regs{"EDI"}, rm => %regs{"ESI"}), 0xFE, "MOV ESI, EDI is 0xFE";
};

subtest "Boundary tests" => {
    is pack-modrm(mod => 0, reg => 0, rm => 0), 0x00, "All zero is 0x00";
    is pack-modrm(mod => 3, reg => 7, rm => 7), 0xFF, "All max is 0xFF";
};