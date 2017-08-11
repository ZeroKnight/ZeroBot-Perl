package ZeroBot::IRC::Event;

use strictures 2;

use Carp;
use ZeroBot::Common {import => [qw(types)]};
use IRC::Utils qw(parse_user);

use Moo::Role;

has network => (
  is  => 'ro',
  isa => InstanceOf['ZeroBot::IRC::Network'],
  required => 1,
);

has src => (
  is       => 'rwp',
  isa      => Str,
  required => 1,
  trigger  => sub {
    # Update individual accessors when changed
    my ($self, $value) = @_;
    my %parts;
    my @types = qw/nick user host/;

    no strict 'refs';
    @parts{@types} = parse_user($value);
    foreach (@types)
    {
      my $m = "_set_src_$_";
      my $h = "has_src_$_";
      $self->$m($parts{$_}) if $self->$h;
    }
  }
);

has src_nick => (
  is        => 'rwp',
  isa       => IRC_Nick,
  lazy      => 1,
  predicate => 1,
  init_arg  => undef,
  builder   => sub { parse_user($_[0]->src) },
);

has src_user => (
  is        => 'rwp',
  isa       => IRC_User,
  lazy      => 1,
  predicate => 1,
  init_arg  => undef,
  builder   => sub { (parse_user($_[0]->src))[1] },
);

has src_host => (
  is        => 'rwp',
  isa       => Str,
  lazy      => 1,
  predicate => 1,
  init_arg  => undef,
  builder   => sub { (parse_user($_[0]->src))[2] },
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

sub BUILD
{
  my ($self, $args) = @_;
  croak "Must initialize either dests or dest, but not both"
    unless $args->{dests} xor $args->{dest};
}

1;
