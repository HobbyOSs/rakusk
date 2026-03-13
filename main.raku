use v6;
use JSON::Fast;

# 1. 外部データの読み込み
my $data = from-json("data/instructions.json".IO.slurp);
my %REGS = $data<registers>;
my %INST = $data<instructions>;

# 引数の有無で命令を分ける
my @inst_with_ops = %INST.grep({ .value<type> ne 'no-op' }).map(*.key).sort({ $^b.chars <=> $^a.chars });
my @inst_no_ops   = %INST.grep({ .value<type> eq 'no-op' }).map(*.key).sort({ $^b.chars <=> $^a.chars });

# PEGの設計思想を忠実に再現したGrammar
grammar Assembler {
    token TOP { ^ <statement>* $ }

    token statement {
        <ws>*
        [
        | <mnemonic_stmt>
        | <opcode_stmt>
        | <comment>
        | <empty>
        ]
        <ws>*
        [ \n | $ ]
        <?{ $/.chars > 0 }> # 無限ループ防止：1文字以上消費
    }

    # 引数あり: オペコード + 空白(WS) + 引数リスト
    token mnemonic_stmt {
        <mnemonic_op_req> \s+ <operand_list>
    }

    # 引数なし: オペコードのみ
    token opcode_stmt {
        <mnemonic_op_none>
    }

    token mnemonic_op_req  { :i @( @inst_with_ops ) }
    token mnemonic_op_none { :i @( @inst_no_ops ) }

    token operand_list {
        <operand> [ \s* ',' \s* <operand> ]*
    }

    token operand { <reg> | <imm> }
    token reg     { :i @( %REGS.keys.sort({ $^b.chars <=> $^a.chars }) ) }
    token imm     { :i [ '0x' <[0..9a..f]>+ | <[0..9]>+ ] }

    token comment { ';' \N* }
    token ws      { <[ \t ]> }
    token empty   { <?> }
}

class AssemblerActions {
    method TOP($/) {
        make Buf.new($<statement>».made.grep(*.defined).map(*.list).flat);
    }

    method statement($/) {
        if $<mnemonic_stmt> { make $<mnemonic_stmt>.made }
        elsif $<opcode_stmt> { make $<opcode_stmt>.made }
        else { make Nil }
    }

    method opcode_stmt($/) {
        my $m = $<mnemonic_op_none>.uc;
        my $info = %INST{$m};
        make Buf.new($info<opcode>.parse-base(16));
    }

    method mnemonic_stmt($/) {
        my $m = $<mnemonic_op_req>.uc;
        my $info = %INST{$m};
        
        if $info<type> eq 'reg-imm8' {
            my $ops = $<operand_list><operand>;
            my $reg_name = $ops[0]<reg>.uc;
            my $imm_str  = $ops[1]<imm>.Str;
            my $imm_val  = $imm_str.starts-with('0x', :i) 
                           ?? $imm_str.substr(2).parse-base(16) 
                           !! $imm_str.parse-base(10);
            
            my $opcode = $info<base_opcode>.parse-base(16) + %REGS{$reg_name};
            make Buf.new($opcode, $imm_val);
        }
    }
}

sub build-and-test(Str $code) {
    say "--- Debug Info ---";
    say "Code to parse:\n[$code]";
    
    my $match = Assembler.parse($code, :actions(AssemblerActions.new));
    if $match {
        my $bin = $match.made;
        "boot.bin".IO.spurt($bin);
        say "Binary: " ~ $bin.list.map({ .fmt('%02X') }).join(' ');
        shell "ndisasm -b16 boot.bin";
    } else {
        say "Parse failed!";
    }
}

# テスト実行
build-and-test("MOV AL, 0x12\nHLT");