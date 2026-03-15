use v6;
use lib 'lib';
use Rakusk::Grammar;

sub test-parse($token, $text) {
    say "--- Testing $token with '$text' ---";
    my $m = Assembler.parse($text, :rule($token));
    if $m {
        say "OK: «{$m.Str}»";
        for $m.caps -> $cap {
            say "  {$cap.key}: «{$cap.value.Str}»";
        }
    } else {
        say "FAIL";
    }
}

# ident の定義を確認するためのテスト
test-parse('ident', ".from_app");
test-parse('ident', ".from_app:"); # これがどこまでマッチするか

# label のテスト
test-parse('label', ".from_app:");

# label_stmt のテスト
test-parse('label_stmt', ".from_app:");

# statement のテスト
test-parse('statement', ".from_app:\n");

# 空白を含めた ident のマッチング確認
# もし文字クラスに空白が含まれているなら、これもマッチしてしまうはず
test-parse('ident', "abc def");