use v6;
use Test;
use lib 'lib';
use Rakusk;

plan 4;

# reg-reg 命令はオペランドの幅でオプコードを選ぶ。
# 8ビット同士なら 8ビット用オプコード (MOV 88, ADD 00, SUB 28, AND 20,
# OR 08, XOR 30, CMP 38)、16/32ビット同士なら 16/32ビット用 (MOV 89,
# ADD 01, SUB 29, AND 21, OR 09, XOR 31, CMP 39) になること。
# 以前は幅を見ず、MOV/ADD/SUB/AND/OR/XOR は常に 16/32ビット用、
# CMP は常に 8ビット用になっていた (ipl09.nas の readfast が
# SUB AL,AH 等で壊れる原因)。

subtest "8-bit reg-reg" => {
    is-deeply assemble("MOV AL, BL").binary.list, (0x88, 0xD8), "MOV AL, BL";
    is-deeply assemble("MOV AH, BL").binary.list, (0x88, 0xDC), "MOV AH, BL";
    is-deeply assemble("MOV AL, AH").binary.list, (0x88, 0xE0), "MOV AL, AH";
    is-deeply assemble("MOV BH, DH").binary.list, (0x88, 0xF7), "MOV BH, DH";
    is-deeply assemble("ADD AL, BL").binary.list, (0x00, 0xD8), "ADD AL, BL";
    is-deeply assemble("ADD AH, BH").binary.list, (0x00, 0xFC), "ADD AH, BH";
    is-deeply assemble("SUB AL, AH").binary.list, (0x28, 0xE0), "SUB AL, AH";
    is-deeply assemble("SUB AH, CL").binary.list, (0x28, 0xCC), "SUB AH, CL";
    is-deeply assemble("SUB BH, AH").binary.list, (0x28, 0xE7), "SUB BH, AH";
    is-deeply assemble("AND CH, AL").binary.list, (0x20, 0xC5), "AND CH, AL";
    is-deeply assemble("OR DH, CL").binary.list, (0x08, 0xCE), "OR DH, CL";
    is-deeply assemble("XOR AH, AH").binary.list, (0x30, 0xE4), "XOR AH, AH";
    is-deeply assemble("CMP AL, AH").binary.list, (0x38, 0xE0), "CMP AL, AH";
    is-deeply assemble("CMP AH, BH").binary.list, (0x38, 0xFC), "CMP AH, BH";
}

subtest "16-bit reg-reg" => {
    is-deeply assemble("MOV AX, BX").binary.list, (0x89, 0xD8), "MOV AX, BX";
    is-deeply assemble("MOV SP, BX").binary.list, (0x89, 0xDC), "MOV SP, BX";
    is-deeply assemble("ADD DX, SP").binary.list, (0x01, 0xE2), "ADD DX, SP";
    is-deeply assemble("SUB SI, DI").binary.list, (0x29, 0xFE), "SUB SI, DI";
    is-deeply assemble("AND BP, AX").binary.list, (0x21, 0xC5), "AND BP, AX";
    is-deeply assemble("OR BX, SI").binary.list, (0x09, 0xF3), "OR BX, SI";
    is-deeply assemble("CMP AX, BX").binary.list, (0x39, 0xD8), "CMP AX, BX";
}

subtest "32-bit reg-reg in 16-bit mode" => {
    is-deeply assemble("MOV EAX, EBX").binary.list, (0x66, 0x89, 0xD8), "MOV EAX, EBX";
    is-deeply assemble("XOR EBX, EAX").binary.list, (0x66, 0x31, 0xC3), "XOR EBX, EAX";
    is-deeply assemble("CMP ESP, EBP").binary.list, (0x66, 0x39, 0xEC), "CMP ESP, EBP";
}

subtest "ipl09 readfast fragment" => {
    # haribote ipl09.nas の readfast に現れる並び
    my $src = "SUB AL,AH\nMOV AH,BL\nMOV AL,AH\nSUB AH,CL";
    is-deeply assemble($src).binary.list,
        (0x28, 0xE0, 0x88, 0xDC, 0x88, 0xE0, 0x28, 0xCC),
        "readfast 8-bit sequence";
}

done-testing;
