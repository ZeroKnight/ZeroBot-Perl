package ZeroBot::Log::Settings;

use ZeroBot::Common -types;

use Moo::Role;

has output_format => (
  is  => 'rw',
  isa => Str,
  default => sub { '[%level] %time %msg' },
  predicate => 1,
);

has time_format => (
  is  => 'rw',
  isa => Str,
  default => sub { '%F %T' },
  predicate => 1,
);

1;
