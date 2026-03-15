use v6;

sub MAIN(Str $nas_file, Str $test_name) {
    my $nas_content = $nas_file.IO.slurp(:bin).decode('latin1');
    my $bin_file = "$test_name.bin";
    my $lst_file = "$test_name.lst";
    
    # Run nask.exe via wine
    shell "wine ~/.wine/drive_c/MinGW/msys/1.0/bin/nask.exe $nas_file $bin_file $lst_file";
    
    if ! $bin_file.IO.e {
        die "Failed to generate $bin_file";
    }
    
    my $bin_data = $bin_file.IO.slurp(:bin);
    my $hex_list = $bin_data.list.map({ "0x" ~ .fmt("%02x") }).join(", ");
    
    my $template = Q:to/T/;
use v6;
use Test;
use Rakusk;
use lib 't';
use TestHelper;

subtest "TEST_NAME" => {
    my $asm = q:to/ASM/;
NAS_CONTENT
ASM

    my $expected = Buf.new(
HEX_LIST
    );

    my $res = assemble($asm);
    my $actual = $res.binary;
    is-binary($actual, $expected, "TEST_NAME binary match");
}

done-testing;
T

    $template ~~ s:g/TEST_NAME/$test_name/;
    $template ~~ s/NAS_CONTENT/$nas_content/;
    $template ~~ s/HEX_LIST/$hex_list/;
    
    "t/day06_$test_name.t".IO.spurt($template);
    say "Generated t/day06_$test_name.t";
}
