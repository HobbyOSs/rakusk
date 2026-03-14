use Test;
use lib 't';
use TestHelper;

plan 3;

subtest "define-hex" => {
    plan 4;
    
    my $buf1 = define-hex([
        "DATA 0xb8 0x01 0x00",
        "DATA 144",
        "DATA \"ABC\"",
    ]);
    is-deeply $buf1, Buf.new(0xb8, 0x01, 0x00, 144, 65, 66, 67), "DATA command handles hex, int, and string";

    my $buf2 = define-hex([
        "FILL 4 0x90",
    ]);
    is-deeply $buf2, Buf.new(0x90, 0x90, 0x90, 0x90), "FILL command handles count and hex value";

    my $buf3 = define-hex([
        "DATA 0x01 # comment",
        "# full line comment",
        "  ",
        "DATA 0x02",
    ]);
    is-deeply $buf3, Buf.new(0x01, 0x02), "Comments and empty lines are ignored";

    my $buf4 = define-hex([
        "FILL 2",
    ]);
    is-deeply $buf4, Buf.new(0, 0), "FILL command defaults to 0";
};

subtest "hexdump" => {
    plan 1;
    my $buf = Buf.new(0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x21, (0) xx 10);
    my $dump = hexdump($buf);
    like $dump, / "000000  48 65 6c 6c 6f 21 00 00 00 00 00 00 00 00 00 00  'Hello!..........'" /, "hexdump format is correct";
};

subtest "hex-diff" => {
    plan 1;
    my $expected = Buf.new(0x01);
    my $actual = Buf.new(0x02);
    my $diff = hex-diff($expected, $actual);
    like $diff, / "Expected" .* "Actual" /, "hex-diff contains both labels";
};