package ZeroBot::IRC::ServerReply;
# Represents an arbitrary server reply (RPL_*, ERR_*)

use ZeroBot::Common -types;

use Moose;
use MooseX::AttributeShortcuts;

has network => (
  is       => 'ro',
  isa      => 'ZeroBot::IRC::Network',
  required => 1,
);

has src => (
  is       => 'ro',
  isa      => 'ZeroBot::IRC::Server',
  required => 1,
);

has numeric => (
  is       => 'ro',
  isa      => 'Int',
  required => 1,
);

has rawmsg => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has msg => (
  is       => 'ro',
  isa      => 'ArrayRef',
  required => 1,
);

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;
  return $class->$orig(
    network => $args[0],
    numeric => $args[1],
    src     => $args[0]->connected_server,
    rawmsg  => $args[2],
    msg     => $args[3]
  );
};

1;
