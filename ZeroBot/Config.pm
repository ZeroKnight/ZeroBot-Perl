package ZeroBot::Config;

use ZeroBot::Common -types;

use ZeroBot::Config::File::Core;
use ZeroBot::Config::File::Plugin;

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

has plugins_file => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::Config::File::Plugin'],
  lazy     => 1,
  init_arg => undef,
  builder  => sub {
    my $self = shift;
    ZeroBot::Config::File::Plugin->new(
      filepath => $self->_cfg_path($self->paths->{plugins})
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

has plugins => (
  is      => 'ro',
  isa     => HashRef,
  lazy    => 1,
  init_arg => undef,
  builder  => sub { $_[0]->plugins_file->data; },
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
  $self->plugins_file;
}

sub _build_paths
{
  my $self = shift;
  return {
    config  => 'config',
    core    => 'zerobot.yaml',
    plugins => 'plugins.yaml',
  };
}

sub _cfg_path
{
  my ($self, $path) = @_;
  return $self->paths->{config}->child($path);
}

1;
