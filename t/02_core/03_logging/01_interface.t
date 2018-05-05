use strictures 2;
use Test::More tests => 2;

BEGIN { use_ok('ZeroBot::Log') }

can_ok('ZeroBot::Log', qw(
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
));

# TODO: test methods
