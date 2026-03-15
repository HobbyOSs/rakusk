use v6;

unit module Rakusk::Log;

enum Level is export <DEBUG INFO WARN ERROR>;

my $current-level = Level::INFO;

if %*ENV<RAKUSK_LOG_LEVEL> -> $env-level {
    try {
        $current-level = Level::{$env-level.uc};
    }
}

sub set-level(Level $level) is export { $current-level = $level; }
sub get-level() is export { $current-level; }

sub log(Level $level, $msg) is export {
    return if $level.value < $current-level.value;
    
    my $prefix = do given $level {
        when Level::DEBUG { "[DEBUG] " }
        when Level::INFO  { "[INFO]  " }
        when Level::WARN  { "[WARN]  " }
        when Level::ERROR { "[ERROR] " }
    };
    
    note $prefix ~ $msg;
}

sub debug($msg) is export { log(Level::DEBUG, $msg); }
sub info($msg)  is export { log(Level::INFO,  $msg); }
sub warn($msg)  is export { log(Level::WARN,  $msg); }
sub error($msg) is export { log(Level::ERROR, $msg); }
