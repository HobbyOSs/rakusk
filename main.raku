use v6;
use lib 'lib';
use Rakusk;

use Rakusk::Log;

#| rakusk: Raku-based x86 Assembler
sub MAIN(
    Str $file?,               #= 入力ファイルパス（指定がない場合は標準入力から読み込み）
    Bool :v(:$verbose) = False,  #= デバッグログを表示
    Bool :i(:$show-info) = False #= 命令のサイズと情報を表示
) {
    if $verbose {
        set-level(DEBUG);
    }

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

    my $res = assemble($code);
    my $bin = $res.binary;

    if $show-info {
        say "\n--- Instruction Information ---";
        for $res.listing -> $item {
            # say "Item keys: " ~ $item.keys.join(', ');
            next unless $item<bin>;
            printf "0x%04X: [%-20s] %-12s size=%d  %s\n",
            $item<pc>,
            $item<bin>.list.map({ .fmt('%02X') }).join(' '),
            $item<type>,
            $item<size>,
            $item<node>.mnemonic;
        }
        say "-------------------------------\n";
    }

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
