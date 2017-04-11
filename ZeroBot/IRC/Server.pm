package ZeroBot::IRC::Server;

use strictures 2;

use Moo;
use Types::Standard qw(Int Str Bool);

has hostname => (
  is       => 'rw',
  isa      => Str,
  required => 1,
);

has port => (
  is      => 'rw',
  isa     => Int,
  default => 6667,
);

has password => (
  is  => 'rw',
  isa => Str,
);

has ssl => (
  is  => 'rw',
  isa => Bool,
  default => 0,
);

has ipv6 => (
  is  => 'rw',
  isa => Bool,
  default => 0,
);

1;
