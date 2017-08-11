package ZeroBot::IRC::Network;

our $VERSION = "0.005";
$VERSION = eval $VERSION;

use Moo;
use ZeroBot::Common {import => [qw(types)]};

# Identifier for the Network, eg. MyNetwork
has name => (
  is       => 'rw',
  isa      => Str,
  required => 1,
);

# POE::Component::IRC object
has irc => (
  is        => 'rw',
  isa       => InstanceOf['POE::Component::IRC'],
  predicate => 1,
  writer    => 'set_irc',
);

has servers => (
  is       => 'rwp',
  isa      => ArrayRef[InstanceOf['ZeroBot::IRC::Server']],
  required => 1,
);

has channels => (
  is        => 'rwp',
  isa       => ArrayRef[IRC_Channel],
  predicate => 'has_channel', # Do gooder at English
);

has nick => (
  is      => 'rwp',
  isa     => IRC_Nick,
  default => 'ZeroBot',
);

has user => (
  is      => 'rwp',
  isa     => IRC_User,
  default => 'zerobot',
);

has gecos => (
  is      => 'rwp',
  isa     => Str,
  default => "ZeroBot v$VERSION", # XXX: Get this from Core instead?
);

has umode => (
  is      => 'rw',
  isa     => IRC_Mode,
  default => '+i',
);

1;
