use v6;
unit module Rakusk::Pass1;
use JSON::Fast;
use Rakusk::AST;

our $DEFAULT_INST_PATH = "data/instructions.json";

class Pass1 is export {
    has %.symbols;
    has @.ast;
    has Int $.pc = 0;

    method evaluate($match, %regs) {
        @!ast = $match.made;
        
        # パス1: ラベルの収集とPCの計算
        $!pc = 0;
        for @!ast -> $node {
            # ORG 命令の特別な処理
            if $node ~~ PseudoNode && $node.mnemonic eq 'ORG' {
                $!pc = $node.operands[0];
                next;
            }

            # TODO: ラベルの収集 (現在は未実装)

            if $node ~~ InstructionNode {
                $!pc += $node.encode(%regs).elems;
            }
            elsif $node ~~ PseudoNode {
                $!pc += $node.encode($!pc).elems;
            }
        }
        return self;
    }
}

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
            my @ops = $<operand_list><operand>;
            my $reg_name = @ops[0]<reg>.uc;
            my $imm_val  = self.parse-imm(@ops[1]<imm>);
            
            make InstructionNode.new(
                mnemonic => $m,
                operands => [$reg_name, $imm_val],
                info     => $info
            );
        }
        elsif $info<type> eq 'pseudo' {
            my @ops_nodes = $<operand_list><operand>;
            my @operands;
            for @ops_nodes -> $op_node {
                if $op_node<imm> {
                    @operands.push(self.parse-imm($op_node<imm>));
                }
                elsif $op_node<string_lit> {
                    @operands.push($op_node<string_lit>.Str);
                }
                elsif $op_node<symbol_pc> {
                    # TODO: $ の解決。現在はとりあえず0か何かを入れる
                    @operands.push(0); 
                }
            }
            make PseudoNode.new(
                mnemonic => $m,
                operands => @operands
            );
        }
    }

    method parse-imm($imm_match) {
        my $str = $imm_match.Str;
        my $sign = 1;
        if $str.starts-with('-') {
            $sign = -1;
            $str = $str.substr(1);
        }

        if $str.starts-with('0x', :i) {
            return $sign * $str.substr(2).parse-base(16);
        }
        else {
            return $sign * $str.parse-base(10);
        }
    }
}
