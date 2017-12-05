package ZeroBot::Util::File;

use ZeroBot::Common -types;

use Moo::Role;
use Path::Tiny;
use Types::Path::Tiny qw(Path);

has filepath => (
  is       => 'ro',
  isa      => Path,
  required => 1,
  coerce   => 1,
);

has filename => (
  is       => 'ro',
  isa      => Str,
  init_arg => undef,
  lazy     => 1,
  builder  => sub { $_[0]->filepath->basename },
);

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;

  if (@args == 1 && !ref $args[0])
  {
    return $class->$orig(filepath => $args[0]);
  }

  return $class->$orig(@args);
};

1;
