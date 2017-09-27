package ZeroBot::Config;

use ZeroBot::Common -types;

use ZeroBot::Config::File::Core;
use ZeroBot::Config::File::Plugin;

use Moo;
use Path::Tiny;
use Types::Path::Tiny qw(Path);

# Path where ZeroBot's configuration files are stored
has config_dir => (
  is      => 'ro',
  isa     => Path,
  # TODO: Change this down the line to $XDG_CONFIG_HOME
  default => sub { path('config') },
  coerce  => 1,
);

has core_cfg_path => (
  is      => 'ro',
  isa     => Path,
  default => sub { path('ZeroBot.yaml') },
  coerce  => 1,
);

has plugins_cfg_path => (
  is      => 'ro',
  isa     => Path,
  default => sub { path('plugins.yaml') },
  coerce  => 1,
);

has core_cfg => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::Config::File::Core'],
  lazy     => 1,
  init_arg => undef,
  builder  => sub {
    my $self = shift;
    ZeroBot::Config::File::Core->new(
      filepath => $self->_make_cfg_path($self->core_cfg_path)
    );
  },
);

has plugins_cfg => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::Config::File::Plugin'],
  lazy     => 1,
  init_arg => undef,
  builder  => sub {
    my $self = shift;
    ZeroBot::Config::File::Plugin->new(
      filepath => $self->_make_cfg_path($self->plugins_cfg_path)
    );
  },
);

# Convenient config section accessors

has core => (
  is       => 'ro',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->core_cfg->data->{Core}; },
);

# has plugins => (
#   is      => 'ro',
#   isa     => ...,
#   builder => ...,
# );

has irc => (
  is       => 'ro',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->core_cfg->data->{IRC}; },
);

sub BUILD
{
  my $self = shift;

  # Run *_cfg builders
  $self->core_cfg;
  $self->plugins_cfg;
}

sub _make_cfg_path
{
  my ($self, $path) = @_;
  $path = $self->config_dir . "/$path" if $path->is_relative;
  return $path;
}

1;
