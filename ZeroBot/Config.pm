package ZeroBot::Config;

use ZeroBot::Common -types;

use ZeroBot::Config::File::Core;
use ZeroBot::Config::File::Module;

use Moo;
use Path::Tiny;
use Types::Path::Tiny qw(Path);

has paths => (
  is      => 'ro',
  isa     => HashRef,
  builder => 1,
);

has core_file => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::Config::File::Core'],
  lazy     => 1,
  init_arg => undef,
  builder  => sub {
    my $self = shift;
    ZeroBot::Config::File::Core->new(
      filepath => $self->_cfg_path($self->paths->{core})
    );
  },
);

has modules_file => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::Config::File::Module'],
  lazy     => 1,
  init_arg => undef,
  builder  => sub {
    my $self = shift;
    ZeroBot::Config::File::Module->new(
      filepath => $self->_cfg_path($self->paths->{modules})
    );
  },
);

# Convenient config section accessors

has core => (
  is       => 'ro',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->core_file->data; },
);

has modules => (
  is      => 'ro',
  isa     => HashRef,
  lazy    => 1,
  init_arg => undef,
  builder  => sub { $_[0]->modules_file->data; },
);

has irc => (
  is       => 'ro',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->core_file->data->{IRC}; },
);

sub BUILD
{
  my $self = shift;

  # Upgrade raw path strings to Path::Tiny objects
  while (my ($k, $v) = each %{$self->paths})
  {
    $self->paths->{$k} = path($v);
  }

  # Run builders
  $self->core_file;
  $self->modules_file;
}

sub _build_paths
{
  my $self = shift;
  return {
    config  => 'config',
    core    => 'zerobot.yaml',
    modules => 'modules.yaml',
  };
}

sub _cfg_path
{
  my ($self, $path) = @_;
  return $self->paths->{config}->child($path);
}

1;
