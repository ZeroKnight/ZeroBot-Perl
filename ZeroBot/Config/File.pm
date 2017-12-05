package ZeroBot::Config::File;

use ZeroBot::Common -types;

use Carp;
use Path::Tiny;
use Types::Path::Tiny qw(Path);
use YAML::XS qw(LoadFile DumpFile);

use Moo;
with 'ZeroBot::Util::File';

# Holds the deserialized configuration file
has data => (
  is       => 'rwp',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->read() },
);

sub BUILD
{
  my $self = shift;
  $self->data;
}

sub read
{
  my $self = shift;
  my $file = $self->filepath;
  my $yaml = try { LoadFile($file) } catch {
    croak "Failed to load config file: $_";
  };
  try { $self->validate($yaml) } catch {
    croak "Failed to validate config file $file: $_";
  };
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

  Log->info("Rehashing config file: $file");
  my $cfg = $self->read($file);
  $self->_set_data($cfg);
}

sub validate
{
  my ($self, $data) = @_;
  Log->warning('No validation for config file: ' . $self->filename) if Log;
  1;
}

1;
