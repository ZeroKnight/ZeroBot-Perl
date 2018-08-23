package ZeroBot::IRC::User;

use ZeroBot::Common -types;

use IRC::Utils qw(parse_user);

use Moo;

has hostmask => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has nick => (
  is        => 'rwp',
  isa       => IRC_Nickname,
  lazy      => 1,
  predicate => 1,
  init_arg  => undef,
  builder   => sub { parse_user($_[0]->hostmask) },
);

has user => (
  is        => 'rwp',
  isa       => IRC_Username,
  lazy      => 1,
  predicate => 1,
  init_arg  => undef,
  builder   => sub { (parse_user($_[0]->hostmask))[1] },
);

has hostname => (
  is        => 'rwp',
  isa       => Str,
  lazy      => 1,
  predicate => 1,
  init_arg  => undef,
  builder   => sub { (parse_user($_[0]->hostmask))[2] },
);

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;
  if (@args == 1 && !ref $args[0])
  {
    return $class->$orig(hostmask => $args[0]);
  }
  return $class->$orig(@args);
};

1;
