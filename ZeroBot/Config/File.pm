package ZeroBot::Config::File;

use ZeroBot::Common -types;

use Carp;
use Path::Tiny;
use Types::Path::Tiny qw(Path);
use YAML::XS qw(LoadFile DumpFile);

use Moo;

# Path to the config file itself
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

# Holds the deserialized configuration file
has data => (
  is       => 'rwp',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->read($_[0]->filepath); },
);

sub BUILD
{
  my $self = shift;
  $self->data;
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
  my $file = $self->filepath;

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
