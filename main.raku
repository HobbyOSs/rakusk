use v6;
use lib 'lib';
use Rakusk;

sub build-and-test(Str $code) {
    say "--- Debug Info ---";
    say "Code to parse:\n[$code]";
    
    my $bin = assemble($code);
    if $bin {
        "boot.bin".IO.spurt($bin);
        say "Binary: " ~ $bin.list.map({ .fmt('%02X') }).join(' ');
        shell "ndisasm -b16 boot.bin";
    } else {
        say "Parse failed!";
    }
}

# テスト実行
build-and-test("MOV AL, 0x12\nCLI\nSTI\nNOP\nPUSHA\nPOPA\nHLT");