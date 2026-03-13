use v6;
unit module Rakusk;
use Rakusk::Grammar;
use Rakusk::Pass1;
use Rakusk::Pass2;
use JSON::Fast;

our $DEFAULT_INST_PATH = "data/instructions.json";

our sub assemble(Str $source) is export {
    # 1. データの読み込み
    my $data = from-json($DEFAULT_INST_PATH.IO.slurp);
    my %regs = $data<registers>;

    # 2. Grammar と Actions の適用 (Pass 1)
    my $actions = AssemblerActions.new();
    my $match = Assembler.parse($source, :$actions);
    unless $match {
        die "Syntax error in assembly source";
    }

    my $pass1 = Pass1.new().evaluate($match, %regs);

    # 3. Pass 2
    my $pass2 = Pass2.new(:$pass1);
    return $pass2.assemble(%regs);
}