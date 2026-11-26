use v6;
use Test;
use lib 'lib';
use Rakusk;

plan 5;

# メモリオペランドの変位の符号と、複数の変位の合計の回帰テスト。
# 以前は [EDI-4] の '-' が捨てられて [EDI+4] になり、
# [ESP+4+40] は先頭の 4 しか使われなかった。

my $h = "[BITS 32]\n";

is-deeply assemble($h ~ "MOV [EDI-4],EAX").binary.list, (0x89, 0x47, 0xFC), "negative disp8";
is-deeply assemble($h ~ "MOV EAX,[EBP-8]").binary.list, (0x8B, 0x45, 0xF8), "negative disp with EBP base";
is-deeply assemble($h ~ "MOV EAX,[ESP+4+40]").binary.list, (0x8B, 0x44, 0x24, 0x2C), "two disps are summed";
is-deeply assemble($h ~ "MOV EAX,[ESP+EAX*4-16]").binary.list, (0x8B, 0x44, 0x84, 0xF0), "negative disp with index and scale";
is-deeply assemble($h ~ "MOV EAX,[ESI+20]").binary.list, (0x8B, 0x46, 0x14), "positive disp unchanged";

done-testing;
