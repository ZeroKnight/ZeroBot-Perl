package ZeroBot::IRC::Event;

use ZeroBot::Common -types;
use ZeroBot::IRC::User;

use Carp;

use Moo::Role;

has network => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::IRC::Network'],
  required => 1,
);

has src => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::IRC::User'],
  required => 1,
);

has dests => (
  is      => 'rwp',
  isa     => ArrayRef,
  lazy    => 1,
  builder => sub { [ $_[0]->dest ] },
  trigger => sub { $_[0]->_set_dest($_[1]->[0]) },
);

# Shortcut for first (or only) destination
has dest => (
  is      => 'rwp',
  isa     => Str,
  lazy    => 1,
  builder => sub { $_[0]->dests->[0] },
  trigger => sub { $_[0]->dests->[0] = $_[1] },
);

has time => (
  is      => 'ro',
  isa     => Int,
  default => sub { time },
);

sub BUILD
{
  my ($self, $args) = @_;
  croak "Must initialize either dests or dest, but not both"
    unless $args->{dests} xor $args->{dest};
}

1;
