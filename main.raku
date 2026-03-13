use v6;

# 1. 文法定義：AIが今後ここを拡張していく
grammar Assembler {
    token TOP         { <instruction>+ }
    token instruction { <mnemonic> \s* }
    token mnemonic    { :i "HLT" | "CLI" } # ここに命令を追加していく
}

# 2. 意味解析（バイナリ生成）：パズルを組み立てる場所
class AssemblerActions {
    method TOP($/) {
        make $/.<instruction>.map(*.made).reduce({ $^a ~ $^b });
    }
    method instruction($/) {
        make $/.<mnemonic>.made;
    }
    method mnemonic($/) {
        my %opcodes = "HLT" => 0xF4, "CLI" => 0xFA;
        make Buf.new(%opcodes{$/.uc});
    }
}

# 3. 実行と検証パイプライン
sub build-and-test(Str $code) {
    my $match = Assembler.parse($code, :actions(AssemblerActions.new));
    
    if $match {
        my $bin = $match.made;
        "boot.bin".IO.spurt($bin); # バイナリ書き出し
        say "Build successful. Testing with ndisasm...";
        
        # 外部コマンド ndisasm で答え合わせ
        my $result = shell("ndisasm -b16 boot.bin", :out).out.slurp;
        say "Disassembly result:\n$result";
    } else {
        die "Parse failed!";
    }
}

build-and-test("CLI HLT");