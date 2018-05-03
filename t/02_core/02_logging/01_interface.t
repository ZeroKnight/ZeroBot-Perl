use strictures 2;
use Test::More tests => 1;
use ZeroBot::Log;

my @methods = qw(
  level
  output_format
  time_format
  writers
  add_writers
  del_writers
  get_writer
  fatal
  error
  warning
  info
  debug
  verbose
);

can_ok('ZeroBot::Log', @methods);
