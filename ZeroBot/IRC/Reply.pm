package ZeroBot::IRC::Reply;
# Represents an arbitrary server reply (RPL_*, ERR_*)

use ZeroBot::Common -types;

use Moo;
with 'ZeroBot::IRC::Event';

has '+src' => (isa => Str);

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
    dest    => $args[0]->nick,
    numeric => $args[1],
    src     => $args[2],
    rawmsg  => $args[3],
    msg     => $args[4]
  );
};

1;
