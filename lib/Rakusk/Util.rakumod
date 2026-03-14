use v6;

unit module Rakusk::Util;

# ModR/Mバイトを組み立てる関数
# [ Mod (2bit) | Reg/Opcode (3bit) | R/M (3bit) ]
sub pack-modrm(Int :$mod, Int :$reg, Int :$rm) is export {
    return ($mod +< 6) +| ($reg +< 3) +| $rm;
}
