package ZeroBot::Util::File;

use ZeroBot::Common -types;

use Moo::Role;
use Path::Tiny;
use Types::Path::Tiny qw(Path);

my $re_ext = qr/(?:\.([^.\s]+))+/;

has filepath => (
  is       => 'ro',
  isa      => Path,
  required => 1,
  coerce   => 1,
);

has filename => (
  is       => 'ro',
  isa      => Str,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->filepath->basename },
);

has filename_root => (
  is       => 'rwp',
  isa      => Str,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->filepath->basename($re_ext) },
);

has fileext => (
  is       => 'ro',
  isa      => Str,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->filepath->basename =~ $re_ext and $1 },
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
