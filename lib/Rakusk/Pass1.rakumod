use v6;
use Rakusk::Pass1::Core;

# Rakusk::Pass1::Core を Pass1 という名前で再エクスポートする
sub EXPORT {
    {
        Pass1 => Rakusk::Pass1::Core,
    }
}