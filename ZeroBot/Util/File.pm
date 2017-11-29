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
  isa      => Path,
  init_arg => undef,
  lazy     => 1,
  builder  => sub { $_[0]->filepath->basename },
);

1;
