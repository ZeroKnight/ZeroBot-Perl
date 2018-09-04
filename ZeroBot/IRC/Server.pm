package ZeroBot::IRC::Server;

use strictures 2;

use Moo;
use Types::Standard qw(Int Str Bool);

has hostname => (
  is       => 'rwp',
  isa      => Str,
  required => 1,
);

# A server can report whatever name it wants, and it may not be the same as its
# hostname. This member represents whatever name the server claims.
has servername => (
  is       => 'rwp',
  isa      => Str,
  init_arg => undef,
  default  => sub { $_[0]->hostname },
);

has port => (
  is      => 'rwp',
  isa     => Int,
  default => 6667,
);

has password => (
  is  => 'rwp',
  isa => Str,
);

has ssl => (
  is  => 'rwp',
  isa => Bool,
  default => 0,
);

has ipv6 => (
  is  => 'rwp',
  isa => Bool,
  default => 0,
);

1;
