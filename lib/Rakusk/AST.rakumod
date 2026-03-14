use v6;
use Rakusk::AST::Base;
use Rakusk::AST::Operand;
use Rakusk::AST::Statement;
use Rakusk::AST::Expression;
use Rakusk::AST::Factor;
use Rakusk::AST::Instruction;
use Rakusk::AST::Pseudo;

# unit module は宣言せず、EXPORT サブでエクスポートするシンボルを制御する
sub EXPORT {
    {
        Node           => Rakusk::AST::Base::Node,
        Operand        => Rakusk::AST::Base::Operand,
        Statement      => Rakusk::AST::Base::Statement,
        Register       => Rakusk::AST::Operand::Register,
        Immediate      => Rakusk::AST::Operand::Immediate,
        Memory         => Rakusk::AST::Operand::Memory,
        LabelStmt      => Rakusk::AST::Statement::LabelStmt,
        DeclareStmt    => Rakusk::AST::Statement::DeclareStmt,
        ExportSymStmt  => Rakusk::AST::Statement::ExportSymStmt,
        ExternSymStmt  => Rakusk::AST::Statement::ExternSymStmt,
        ConfigStmt     => Rakusk::AST::Statement::ConfigStmt,
        Expression     => Rakusk::AST::Expression::Expression,
        NumberExp      => Rakusk::AST::Expression::NumberExp,
        ImmExp         => Rakusk::AST::Expression::ImmExp,
        MultExp        => Rakusk::AST::Expression::MultExp,
        AddExp         => Rakusk::AST::Expression::AddExp,
        Factor         => Rakusk::AST::Factor::Factor,
        NumberFactor   => Rakusk::AST::Factor::NumberFactor,
        HexFactor      => Rakusk::AST::Factor::HexFactor,
        CharFactor     => Rakusk::AST::Factor::CharFactor,
        IdentFactor    => Rakusk::AST::Factor::IdentFactor,
        StringFactor   => Rakusk::AST::Factor::StringFactor,
        InstructionNode => Rakusk::AST::Instruction::InstructionNode,
        PseudoNode     => Rakusk::AST::Pseudo::PseudoNode,
    }
}