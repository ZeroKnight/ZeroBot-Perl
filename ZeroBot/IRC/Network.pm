package ZeroBot::IRC::Network;

our $VERSION = "0.005";
$VERSION = eval $VERSION;

use ZeroBot::Common -types;

use Moose;
use MooseX::AttributeShortcuts;
use MooseX::Types::Moose qw(ArrayRef);

# Identifier for the Network, eg. MyNetwork
has name => (
  is       => 'rw',
  isa      => 'Str',
  required => 1,
);

has irc => (
  is        => 'rw',
  isa       => 'POE::Component::IRC',
  predicate => 1,
  writer    => 'set_irc',
  handles   => {
    is_chanop  => 'is_channel_operator',
    yield      => 'yield',
    disconnect => 'disconnect',
  },
);

has servers => (
  is       => 'rwp',
  isa      => 'ArrayRef[ZeroBot::IRC::Server]',
  required => 1,
);

has channels => (
  traits    => ['Hash'],
  is        => 'rwp',
  isa       => 'HashRef[ZeroBot::IRC::Channel]',
  predicate => 'has_channel', # Do gooder at English
  handles   => {
    get_channel       => 'get',
    get_channel_list  => 'keys',
    get_channel_pairs => 'kv',
  },
);

has nick => (
  is      => 'rwp',
  isa     => IRC_Nickname,
  default => 'ZeroBot',
);

# Holds a list of alternate nicks to try at connection registration if the
# primary one is in use
has alt_nicks => (
  is      => 'rw',
  isa     => ArrayRef[IRC_Nickname],
  default => sub { [] }
);

has user => (
  is      => 'rwp',
  isa     => IRC_Username,
  default => 'zerobot',
);

has gecos => (
  is      => 'rwp',
  isa     => 'Str',
  default => "ZeroBot v$VERSION", # XXX: Get this from Core instead?
);

has host => (
  is       => 'rwp',
  isa      => 'Str',
  init_arg => undef,
);

has umode => (
  is      => 'rwp',
  isa     => IRC_Mode,
  default => '+i',
);

has connected => (
  is       => 'rwp',
  isa      => 'Bool',
  default  => 0,
  init_arg => undef,
);

has connected_at => (
  is       => 'rwp',
  isa      => 'Int',
  init_arg => undef,
);

has connected_server => (
  is       => 'rwp',
  isa      => 'ZeroBot::IRC::Server',
  init_arg => undef,
);

sub get_next_alt
{
  my ($self, $reset) = @_;
  state $lastindex = -1;
  if (defined $reset)
  {
    $lastindex = -1;
  }
  else
  {
    return unless @{$self->alt_nicks};
    my $next = $lastindex >= @{$self->alt_nicks} ? $lastindex : ++$lastindex;
    return $self->alt_nicks->[$next];
  }
}

sub get_server
{
  my ($self, $name) = @_;
  foreach my $server (@{$self->servers})
  {
    return $server if $server->servername eq $name;
  }
  return undef;
}

1;
