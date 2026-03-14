use v6;
use Test;
use Rakusk::Grammar;
use Rakusk::AST;

plan *;

my $actions = AssemblerActions.new;

sub parse-stmt($input) {
    my $match = Assembler.parse($input, :actions($actions), :rule('statement'));
    return $match.made;
}

subtest "Basic Operands", {
    my $ast = parse-stmt("MOV AL, 123");
    isa-ok $ast, InstructionNode, "is InstructionNode";
    is $ast.mnemonic, "MOV", "mnemonic is MOV";
    is $ast.operands.elems, 2, "has 2 operands";
    
    isa-ok $ast.operands[0], Register, "first operand is Register";
    is $ast.operands[0].name, "AL", "register name is AL";
    
    isa-ok $ast.operands[1], Immediate, "second operand is Immediate";
    is $ast.operands[1].value, 123, "immediate value is 123";
}

subtest "Labels and Directives", {
    my $ast = parse-stmt("entry:");
    isa-ok $ast, LabelStmt, "is LabelStmt";
    is $ast.label, "entry", "label is 'entry'";

    $ast = parse-stmt("DB 1, 2, 3");
    isa-ok $ast, PseudoNode, "is PseudoNode";
    is $ast.mnemonic, "DB", "mnemonic is DB";
    is $ast.operands.elems, 3, "has 3 operands";
    isa-ok $ast.operands[0], Immediate, "operand is Immediate";
}

subtest "EQU and Config", {
    my $ast = parse-stmt("BOTPAK EQU 0x1234");
    isa-ok $ast, DeclareStmt, "is DeclareStmt";
    is $ast.name, "BOTPAK", "name is BOTPAK";
    is $ast.value.value, 0x1234, "value is 0x1234";

    $ast = parse-stmt("[FORMAT \"WCOFF\"]");
    isa-ok $ast, ConfigStmt, "is ConfigStmt";
    is $ast.type, "FORMAT", "type is FORMAT";
    is $ast.value.value, "WCOFF", "value is WCOFF";
}

done-testing;