use v6;
use JSON::Fast;
use Test;

my $data = from-json("data/instructions.json".IO.slurp);
my %REGS = $data<registers>;
my %INST = $data<instructions>;

grammar Assembler {
    token TOP         { ^ <line>* $ }
    
    token line {
        | \s* \n
        | <statement>
    }

    token statement {
        \s* [ <mnemonic_stmt> | <comment> ] \s* [ \n | $ ]
    }

    rule mnemonic_stmt {
        <mnemonic> <operand_list>?
    }

    token mnemonic {
        :i @( %INST.keys.sort({ $^b.chars <=> $^a.chars }) )
    }

    rule operand_list {
        <operand> [ ',' <operand> ]*
    }

    token operand { <reg> | <imm> }
    token reg     { :i @( %REGS.keys.sort({ $^b.chars <=> $^a.chars }) ) }
    token imm     { :i [ '0x' <[0..9a..f]>+ | <[0..9]>+ ] }

    token comment { ';' \N* }
    token ws      { \s* }
}

plan 8;

ok Assembler.parse("HLT", :rule<mnemonic>), "Mnemonic HLT";
ok Assembler.parse("AL", :rule<reg>), "Register AL";
ok Assembler.parse("0x12", :rule<imm>), "Immediate 0x12";
say "Testing operand match for 'AL':";
my $m_op = Assembler.parse("AL", :rule<operand>);
if $m_op { say "Match op successful: ", $m_op; } else { say "Match op failed"; }

say "Testing operand_list match for 'AL, 0x12':";
my $m = Assembler.parse("AL, 0x12", :rule<operand_list>);
if $m {
    say "Match successful: ", $m;
} else {
    say "Match failed";
}
ok $m, "Operand list 'AL, 0x12'";
ok Assembler.parse("MOV AL, 0x12", :rule<mnemonic_stmt>), "Mnemonic statement 'MOV AL, 0x12'";
ok Assembler.parse("MOV AL, 0x12\n", :rule<statement>), "Statement with newline";
ok Assembler.parse("HLT", :rule<statement>), "Statement without newline (end of string)";

my $code = "MOV AL, 0x12\nHLT";
ok Assembler.parse($code), "Full code parse";

if Assembler.parse($code) {
    say "Full parse successful";
} else {
    say "Full parse failed at offset: ", Assembler.parse($code).?pos // "unknown";
}