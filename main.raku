use v6;
use JSON::Fast;

# 1. 外部データの読み込み
my $inst-data = from-json("data/instructions.json".IO.slurp);
my %opcodes = $inst-data<instructions>.map({ .key => .value<opcode>.parse-base(16) });

# 2. 文法定義：JSONのキーから動的にトークンを生成
grammar Assembler {
    token TOP         { <instruction>+ % \s+ }
    token instruction { <mnemonic> }
    token mnemonic    { 
        :i @( %opcodes.keys ) 
    }
}

# 3. 意味解析：読み込んだハッシュからバイナリを引く
class AssemblerActions {
    method TOP($/) {
        make Buf.new($<instruction>».made.flat);
    }
    method instruction($/) {
        make $<mnemonic>.made;
    }
    method mnemonic($/) {
        make %opcodes{$/.uc};
    }
}

# 4. パイプライン：ビルド・書き出し・検証
sub build-and-test(Str $code) {
    my $match = Assembler.parse($code, :actions(AssemblerActions.new));
    
    if $match {
        my $bin = $match.made;
        "boot.bin".IO.spurt($bin);
        say "--- Build Log ---";
        say "Source: $code";
        say "Binary: " ~ $bin.list.map({ .fmt('%02X') }).join(' ');
        
        # 検証：ndisasmを叩いて逆アセンブル結果を確認
        my $proc = run 'ndisasm', '-b16', 'boot.bin', :out;
        say "--- ndisasm Verification ---\n" ~ $proc.out.slurp;
    } else {
        say "Parse failed! Available mnemonics: " ~ %opcodes.keys.join(', ');
    }
}

# テスト実行
build-and-test("CLI STI HLT");