package ZeroBot::Config;

use ZeroBot::Common -types;

use ZeroBot::Config::File::Core;
use ZeroBot::Config::File::Module;

use Carp;
use Moo;
use Path::Tiny;
use Types::Path::Tiny qw(Path);

my %paths = (
  core    => 'zerobot.cfg',
  modules => 'modules.cfg',
);

has core_file => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::Config::File'],
  lazy     => 1,
  init_arg => undef,
  builder  => sub {
    my $self = shift;
    ZeroBot::Config::File->new(
      filepath => $self->_cfg_path($paths{core})
    );
  },
);

has modules_file => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::Config::File'],
  lazy     => 1,
  init_arg => undef,
  builder  => sub {
    my $self = shift;
    ZeroBot::Config::File->new(
      filepath => $self->_cfg_path($paths{modules})
    );
  },
);

has protocol_files => (
  is       => 'rwp',
  isa      => HashRef[InstanceOf['ZeroBot::Config::File']],
  init_arg => undef,
  builder  => sub { +{} },
);

# Convenient config section accessors

has core => (
  is       => 'ro',
  isa      => HashRef,
  lazy     => 1,
  init_arg => undef,
  builder  => sub { $_[0]->core_file->hash },
);

has modules => (
  is      => 'ro',
  isa     => HashRef,
  lazy    => 1,
  init_arg => undef,
  builder  => sub { $_[0]->modules_file->hash },
);

sub proto
{
  my ($self, $protocol) = @_;
  return $self->protocol_files->{$protocol}{hash};
}

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;
  if (@args == 1 && !ref $args[0])
  {
    # XXX: Avoid creating a pointless duplicate member in this class
    $paths{cfg_dir} = shift @args;
  }
  return $class->$orig(@args);
};

sub BUILD
{
  my $self = shift;

  # Run builders
  $self->core_file;
  $self->modules_file;
}

sub add_protocol_config
{
  my ($self, $protocol) = @_;
  croak 'No protocol specified' unless $protocol;
  $protocol = lc $protocol;
  my $cfg = ZeroBot::Config::File->new(
    filepath => $self->_cfg_path("$protocol.cfg")
  );
  unless (defined $cfg->data)
  {
    Log->error('Failed to load protocol configuration');
    return undef;
  }
  $self->protocol_files->{$protocol} = $cfg;
  return 1;
}

sub get_as_list
{
  my ($self, $val) = @_;
  return ref $val eq 'ARRAY' ? @$val : defined $val ? $val : ();
}

sub _cfg_path
{
  my ($self, $path) = @_;
  return path($paths{cfg_dir})->child($path);
}

1;
