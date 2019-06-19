package ZeroBot::Log::Settings;

use ZeroBot::Common -types;

use Moose::Role;
use MooseX::AttributeShortcuts;

has output_format => (
  is  => 'rw',
  isa => 'Str',
  default => sub { '%time | %levelpad[%level] %msg' },
  predicate => 1,
);

has time_format => (
  is  => 'rw',
  isa => 'Str',
  default => sub { '%F %T' },
  predicate => 1,
);

1;
