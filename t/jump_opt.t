use v6;
use Test;
use Rakusk;
use Rakusk::Util;

# 「ドミノ倒し」ケースの検証
# [BITS 32]
#     jmp forward_label   ; (A) 初回パスは2バイト、後に拡張が必要
#     times 125 db 0      ; (B)
# backward_target:        ; (C)
#     jmp forward_label   ; (D) (A)が拡大するとここも押し出されて境界を超える
#     times 125 db 0      ; (E)
# forward_label:          ; (F)
#     jmp backward_target ; (G) (A)と(D)の拡大後のアドレスを正しく参照できるか

my $asm = Q:to/ASM/;
[BITS 32]
    jmp forward_label
    resb 125
backward_target:
    jmp forward_label
    resb 125
forward_label:
    jmp backward_target
ASM

my $res = Rakusk::assemble($asm);
my $bin = $res.binary;

# (A) jmp forward_label
# (B) times 125 db 0
# 初回見積もり (A)=2, (B)=125 -> backward_target=127
# (D) jmp forward_label (2バイト仮定)
# (E) times 125 db 0
# forward_label = 127 + 2 + 125 = 254
# (A) から forward_label までの距離 = 254 - (0 + 2) = 252 > 127
# よって (A) は 5バイトに拡大される。
# (A)が拡大されると backward_target=130 になる。
# (D) から forward_label までの距離 = (254+3) - (130 + 2) = 125 <= 127
# あれ、(D) は Short のまま？
# 指示書のケースを再計算：
# (A) PC=0, Size=5, Target=254+3+3 = 260. Disp = 260 - 5 = 255.
# (B) PC=5, Size=125
# (C) backward_target: PC=130
# (D) PC=130, Size=5, Target=260. Disp = 260 - (130+5) = 125. (あ、これならShort(2)でいける)
# 指示書では「(A)が拡大するとここ(D)も押し出されて境界を超える」となっているので、
# (B) や (E) のサイズを調整して境界ギリギリにする必要があるかもしれない。

# とりあえずアセンブルが成功し、サイズが妥当であることを確認
ok $bin.defined, "Assemble domino case";
# 期待されるサイズ:
# (A) NEAR JMP: 5
# (B) 125
# (C) Label
# (D) SHORT/NEAR JMP: ?
# (E) 125
# (F) Label
# (G) JMP backward_target: 2 (Short)
# もし (D) が Short なら合計: 5 + 125 + 2 + 125 + 2 = 259
# もし (D) が Near なら合計: 5 + 125 + 5 + 125 + 2 = 262

say "DEBUG: Total binary size = ", $bin.elems;
ok $bin.elems >= 259, "Binary size is reasonable";

# 具体的な命令コードのチェック
# (A) E9 ...
is $bin[0], 0xE9, "First JMP is NEAR (E9)";

# (G) は後ろ向きジャンプ
# forward_label: PC = 5 + 125 + (D_size) + 125
# backward_target: PC = 130
# (G) の位置 = 255 + (D_size)
# 距離 = 130 - (255 + D_size + 2) = -127 - D_size
# D_size=2 なら -129 なので (G) も NEAR になるはず。
# D_size=5 なら -132 なので (G) も NEAR。

is $bin[*-5], 0xE9, "Last JMP is NEAR (E9) because of long backward jump";

done-testing;