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
  is       => 'rw',
  isa      => ArrayRef[InstanceOf['ZeroBot::IRC::Server']],
  required => 1,
);

has channels => (
  is        => 'rw',
  isa       => ArrayRef[IRC_Channel],
  predicate => 'has_channel', # Do gooder at English
);

has nick => (
  is      => 'rw',
  isa     => IRC_Nick,
  default => 'ZeroBot',
);

has user => (
  is      => 'rw',
  isa     => IRC_User,
  default => 'zerobot',
);

has gecos => (
  is      => 'rw',
  isa     => Str,
  default => "ZeroBot v$VERSION", # XXX: Get this from Core instead?
);

has umode => (
  is      => 'rw',
  isa     => IRC_Mode,
  default => '+i',
);

1;
