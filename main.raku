use v6;
use lib 'lib';
use Rakusk;

#| rakusk: Raku-based x86 Assembler
sub MAIN(
    Str $file? #= 入力ファイルパス（指定がない場合は標準入力から読み込み）
) {
    my $code;

    if $file.defined && $file ne '-' {
        if $file.IO.f {
            $code = $file.IO.slurp;
        } else {
            note "Error: File '$file' not found.";
            exit 1;
        }
    } else {
        # 標準入力から読み込み
        $code = $*IN.slurp;
    }

    if $code.trim eq '' {
        note "No input code provided.";
        exit 1;
    }

    my $bin = assemble($code);

    if match_success($bin) {
        "boot.bin".IO.spurt($bin);
        say "Successfully assembled to boot.bin";
        say "Binary (Hex): " ~ $bin.list.map({ .fmt('%02X') }).join(' ');
        
        # 検証（ndisasmが利用可能な場合）
        if shell("which ndisasm > /dev/null 2>&1").exitcode == 0 {
            say "--- Disassembly Check ---";
            shell "ndisasm -b16 boot.bin";
        }
    } else {
        note "Assembly failed!";
        exit 1;
    }
}

sub match_success($val) {
    return $val.defined && $val.elems > 0;
}