package ZeroBot::IRC::ServerReply;
# Represents an arbitrary server reply (RPL_*, ERR_*)

use ZeroBot::Common -types;

use Moose;

has network => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::IRC::Network'],
  required => 1,
);

has src => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::IRC::Server'],
  required => 1,
);

has numeric => (
  is       => 'ro',
  isa      => Int,
  required => 1,
);

has rawmsg => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has msg => (
  is       => 'ro',
  isa      => ArrayRef,
  required => 1,
);

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;
  return $class->$orig(
    network => $args[0],
    numeric => $args[1],
    src     => $args[0]->get_server($args[2]),
    rawmsg  => $args[3],
    msg     => $args[4]
  );
};

1;
