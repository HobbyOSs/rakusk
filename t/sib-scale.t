use v6;
use Test;
use lib 'lib';
use Rakusk;

plan 17;

# SIB のスケール指定と、SBB / XCHG / TEST の reg-reg 形式の回帰テスト。
# スケールは以前は常に 1 倍で固定されており、[ESP+EAX*4+8] のような
# 形が [ESP+EAX+8] として組み立てられていた。
# SBB / XCHG / TEST には reg-reg の定義自体が無かった。
# 期待バイト列は nasm の出力と照合した。XCHG は対称命令のため、
# nasm と rakusk で reg フィールドと r/m フィールドの割り当てが
# 逆になる（意味は同じ）。

my $h = "[BITS 32]\n";

is-deeply assemble($h ~ "MOV EAX,[ESP+EAX*4+8]").binary.list, (0x8B, 0x44, 0x84, 0x08), "scale 4 in SIB";
is-deeply assemble($h ~ "MOV EAX,[ESP+EAX*2+8]").binary.list, (0x8B, 0x44, 0x44, 0x08), "scale 2 in SIB";
is-deeply assemble($h ~ "MOV EAX,[ESP+EAX*8+8]").binary.list, (0x8B, 0x44, 0xC4, 0x08), "scale 8 in SIB";
is-deeply assemble($h ~ "MOV EAX,[ESP+EAX+8]").binary.list, (0x8B, 0x44, 0x04, 0x08), "scale 1 in SIB";
is-deeply assemble($h ~ "SBB EAX,EAX").binary.list, (0x19, 0xC0), "SBB 32bit reg-reg";
is-deeply assemble($h ~ "SBB AL,AH").binary.list, (0x18, 0xE0), "SBB 8bit reg-reg";
is-deeply assemble($h ~ "XCHG EBX,ECX").binary.list, (0x87, 0xCB), "XCHG 32bit reg-reg";
is-deeply assemble($h ~ "XCHG AL,BL").binary.list, (0x86, 0xD8), "XCHG 8bit reg-reg";
is-deeply assemble($h ~ "TEST EAX,EAX").binary.list, (0x85, 0xC0), "TEST 32bit reg-reg";
is-deeply assemble($h ~ "TEST AL,AH").binary.list, (0x84, 0xE0), "TEST 8bit reg-reg";
is-deeply assemble($h ~ "INC EDI").binary.list, (0x47,), "INC 32bit reg";
is-deeply assemble($h ~ "DEC EDI").binary.list, (0x4F,), "DEC 32bit reg";
is-deeply assemble($h ~ "INC AL").binary.list, (0xFE, 0xC0), "INC 8bit reg";
is-deeply assemble($h ~ "MUL ECX").binary.list, (0xF7, 0xE1), "MUL 32bit reg";
is-deeply assemble($h ~ "LEA EDX,[ESI+EAX]").binary.list, (0x8D, 0x14, 0x06), "LEA 32bit reg-mem";
is-deeply assemble($h ~ "LEA EBX,[ESI+ECX+14]").binary.list, (0x8D, 0x5C, 0x0E, 0x0E), "LEA with disp8";
is-deeply assemble($h ~ "MOVZX EAX,[ESI+18]").binary.list, (0x0F, 0xB7, 0x46, 0x12), "MOVZX 32bit reg, word mem";

done-testing;
