use v6;
use Test;
use Rakusk::Grammar;
use Rakusk::Actions;
use Rakusk::AST;

plan *;

my $actions = AssemblerActions.new;

sub parse-expr($input) {
    my $match = Assembler.parse($input, :actions($actions), :rule('exp'));
    return $match.made;
}

subtest "Basic Factors", {
    my $e = parse-expr("30");
    isa-ok $e, ImmExp, "30 is ImmExp";
    is $e.eval({}).value, 30, "eval 30 -> 30";

    $e = parse-expr("0x0ff0");
    is $e.eval({}).value, 0x0ff0, "eval 0x0ff0 -> 4080";

    $e = parse-expr("'A'");
    is $e.eval({}).value, 65, "eval 'A' -> 65";

    $e = parse-expr('"Hello"');
    is $e.eval({}).value, "Hello", 'eval "Hello" -> Hello';
}

subtest "Arithmetic Expressions", {
    my $e = parse-expr("10 + 20");
    isa-ok $e, AddExp, "10 + 20 is AddExp";
    is $e.eval({}).value, 30, "10 + 20 = 30";

    $e = parse-expr("512 * 18 * 2 / 4");
    is $e.eval({}).value, 4608, "512 * 18 * 2 / 4 = 4608";

    $e = parse-expr("10 + 20 * 3");
    is $e.eval({}).value, 70, "10 + 20 * 3 = 70 (precedence check)";

    $e = parse-expr("(10 + 20) * 3");
    is $e.eval({}).value, 90, "(10 + 20) * 3 = 90 (grouping check)";
}

subtest "Expressions with Symbols and PC", {
    my %env = 
        symbols => { CYLS => 10, ADR => 0x1000 },
        PC => 0x7c00;

    my $e = parse-expr("CYLS");
    is $e.eval(%env).value, 10, "eval CYLS -> 10";

    $e = parse-expr("ADR + 0x10");
    is $e.eval(%env).value, 0x1010, "eval ADR + 0x10 -> 0x1010";

    $e = parse-expr('$');
    is $e.eval(%env).value, 0x7c00, 'eval $ -> 0x7c00';

    $e = parse-expr('0x7dfe - $');
    is $e.eval(%env).value, 0x7dfe - 0x7c00, 'eval 0x7dfe - $ -> 0x1f6';
}

subtest "Partial Evaluation", {
    my %env = symbols => { A => 10 };
    
    my $e = parse-expr("A + B");
    my $res = $e.eval(%env);
    isa-ok $res, AddExp, "Partial eval A + B returns AddExp";
    # TODO: We might want partial evaluation to result in "10 + B"
    # But currently it returns self if it can't fully resolve.
}

done-testing;