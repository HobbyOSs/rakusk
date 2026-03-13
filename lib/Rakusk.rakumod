use v6;
unit module Rakusk;

use Rakusk::AST;
use Rakusk::Grammar;
use Rakusk::Pass1;
use Rakusk::Pass2;

# 他のモジュールからインポートできるように再エクスポート
# my constant Assembler is export = Rakusk::Grammar::Assembler;
# 注意: Rakusk::Grammar が既に Assembler を export している場合、ここで再エクスポートすると競合する可能性がある
# 必要に応じてエイリアスを作成

our sub assemble(Str $code) is export {
    my $actions = AssemblerActions.new;
    my $match = Assembler.parse($code, :$actions);
    
    if $match {
        my @ast = $match.made;
        return pass2(@ast, $actions.REGS);
    }
    return Nil;
}