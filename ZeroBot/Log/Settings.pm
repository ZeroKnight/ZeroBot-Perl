package ZeroBot::Log::Settings;

use ZeroBot::Common -types;

use Moo::Role;

has output_format => (
  is  => 'rw',
  isa => Str,
  default => sub { '[%level] %time %msg' },
);

has time_format => (
  is  => 'rw',
  isa => Str,
  default => sub { '%F %T' },
);

1;
