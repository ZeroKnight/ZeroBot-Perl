package ZeroBot::Util::File;

use ZeroBot::Common -types;

use Moose::Role;
use MooseX::AttributeShortcuts;
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
  isa      => 'Str',
  lazy     => 1,
  init_arg => undef,
  default  => sub { $_[0]->filepath->basename },
);

has filename_root => (
  is       => 'rwp',
  isa      => 'Str',
  lazy     => 1,
  init_arg => undef,
  default  => sub { $_[0]->filepath->basename($re_ext) },
);

has fileext => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  init_arg => undef,
  default  => sub { $_[0]->filepath->basename =~ $re_ext and $1 },
);

sub basename_no_ext { $_[0]->basename($re_ext) }

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;

  if (@args == 1 && (!ref $args[0] || ref $args[0] eq 'Path::Tiny'))
  {
    return $class->$orig(filepath => $args[0]);
  }

  return $class->$orig(@args);
};

1;
