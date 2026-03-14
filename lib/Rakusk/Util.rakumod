use v6;
use JSON::Fast;

unit module Rakusk::Util;

our $DEFAULT_INST_PATH = "data/instructions.json";

# データ読み込み用のキャッシュ
my $data = from-json($DEFAULT_INST_PATH.IO.slurp);
our %REGS_DATA is export = $data<registers>;
our %INST_DATA is export = $data<instructions>;

# ModR/Mバイトを組み立てる関数
# [ Mod (2bit) | Reg/Opcode (3bit) | R/M (3bit) ]
sub pack-modrm(Int :$mod, Int :$reg, Int :$rm) is export {
    return ($mod +< 6) +| ($reg +< 3) +| $rm;
}
