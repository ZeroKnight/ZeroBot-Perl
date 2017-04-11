package ZeroBot::Config::File;

use strictures 2;

use Carp;
use Moo;
use Try::Tiny;
use Path::Tiny;
use Types::Path::Tiny qw(Path);
use Types::Standard qw(HashRef);
use YAML::XS qw(LoadFile DumpFile);

# Path to the config file itself
has filepath => (
  is       => 'ro',
  isa      => Path,
  required => 1,
  coerce   => 1,
);

# Holds the deserialized configuration file
has data => (
  is       => 'rwp',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => sub {
    my $self = shift;
    $self->read($self->filepath);
  },
);

has filename => (
  is       => 'ro',
  isa      => Path,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { shift->filepath->basename },
);

sub BUILD
{
  my $self = shift;
  $self->data; # Run data's builder
}

sub read
{
  my ($self, $file) = @_;
  my $yaml = try { LoadFile($file) } catch {
    confess "Failed to load config file: $_";
  };
  try { $self->validate($yaml) } catch {
    croak "Failed to validate config file $file: $_";
  };

  # TODO: proper logging
  CORE::say "Loaded config file: $file";
  return $yaml;
}

sub write
{
  my ($self, $file) = @_;

  ...
}

sub rehash
{
  my $self = shift;
  my $file = $self->path;

  # TODO: proper logging
  CORE::say "Rehashing config file: $file";
  my $cfg = $self->read($file);
  $self->_set_data($cfg);
}

sub validate
{
  my ($self, $cfg) = @_;

  # TODO: proper logging, make this available only in higher-than-default
  # logging levels?
  # CORE::say 'No validation for config file: ', $cfg;
  1;
}

1;
