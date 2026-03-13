use v6;
unit module Rakusk::Pass1;
use JSON::Fast;
use Rakusk::AST;

# 1. 外部データの読み込み（デフォルトパス）
our $DEFAULT_INST_PATH = "data/instructions.json";

class AssemblerActions is export {
    has %.REGS;
    has %.INST;

    submethod TWEAK() {
        # 初期化時にJSONからデータを読み込む
        my $data = from-json($DEFAULT_INST_PATH.IO.slurp);
        %!REGS = $data<registers>;
        %!INST = $data<instructions>;
    }

    method TOP($/) {
        make $<line>».made.grep(*.defined);
    }

    method line($/) {
        make $<statement> ?? $<statement>.made !! Nil;
    }

    method statement($/) {
        if $<mnemonic_stmt> { make $<mnemonic_stmt>.made }
        elsif $<opcode_stmt> { make $<opcode_stmt>.made }
        else { make Nil }
    }

    method opcode_stmt($/) {
        my $m = $<mnemonic_op_none>.uc;
        my $info = %!INST{$m};
        make InstructionNode.new(
            mnemonic => $m,
            info     => $info
        );
    }

    method mnemonic_stmt($/) {
        my $m = $<mnemonic_op_req>.uc;
        my $info = %!INST{$m};
        
        if $info<type> eq 'reg-imm8' {
            my $ops = $<operand_list><operand>;
            my $reg_name = $ops[0]<reg>.uc;
            my $imm_str  = $ops[1]<imm>.Str;
            my $imm_val  = $imm_str.starts-with('0x', :i) 
                           ?? $imm_str.substr(2).parse-base(16) 
                           !! $imm_str.parse-base(10);
            
            make InstructionNode.new(
                mnemonic => $m,
                operands => [$reg_name, $imm_val],
                info     => $info
            );
        }
    }
}