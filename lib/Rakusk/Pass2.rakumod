use v6;
use Rakusk::Pass2::Core;

# Rakusk::Pass2::Core を Pass2 という名前で再エクスポートする
sub EXPORT {
    {
        Pass2 => Rakusk::Pass2::Core,
    }
}