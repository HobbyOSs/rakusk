use v6;
use lib 'lib';
use Rakusk;

use Rakusk::Log;

my $VERSION = "2.0.0";

#| rakusk: Raku-based x86 Assembler
sub MAIN(
    *@args,
    Bool :v(:$version) = False,  #= バージョンとライセンス情報を表示する
    Bool :d(:$debug) = False,    #= デバッグログを出力する
    Bool :i(:$show-info) = False #= 命令のサイズと情報を表示
) {
    if $version {
        say "rakusk $VERSION";
        print Q:to/EOF/;
Copyright (C) 2026 Cline (Original: 2024 idiotpanzer@gmail.com)
ライセンス GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Thank you osask project !
EOF
        exit 0;
    }

    if @args.elems < 2 {
        note "usage:  [--help | -v] source [object/binary] [list]";
        exit 16;
    }

    my $assembly-src = @args[0];
    my $assembly-dst = @args[1];

    if $debug {
        set-level(DEBUG);
    }

    my $code;

    if $assembly-src.IO.f {
        $code = $assembly-src.IO.slurp;
    } else {
        note "RAKUSK : can't open $assembly-src";
        exit 17;
    }

    if $code.trim eq '' {
        note "No input code provided.";
        exit 1;
    }

    say "source: $assembly-src, object: $assembly-dst";

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
        $assembly-dst.IO.spurt($bin);
        # say "Successfully assembled to $assembly-dst";
        # say "Binary (Hex): " ~ $bin.list.map({ .fmt('%02X') }).join(' ');
        
        # 検証（ndisasmが利用可能な場合）
        if $show-info && shell("which ndisasm > /dev/null 2>&1").exitcode == 0 {
            say "--- Disassembly Check ---";
            shell "ndisasm -b16 $assembly-dst";
        }
    } else {
        note "Assembly failed!";
        exit 1;
    }
}

sub match_success($val) {
    return $val.defined && $val.elems > 0;
}
