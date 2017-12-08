package ZeroBot::Core;

use strictures 2;
our $VERSION = '0.005';
$VERSION = eval $VERSION;

use ZeroBot::Config;
use ZeroBot::Log;
use ZeroBot::Module -all;

use POE;
use Try::Tiny;

use Moo;
use Types::Standard qw(HashRef InstanceOf);
with 'MooX::Singleton';

# PoCo::Syndicator comprises the heart of ZeroBot's module (plugin) system
extends 'POE::Component::Syndicator';

has cfg => (
  is       => 'rw',
  isa      => InstanceOf['ZeroBot::Config'],
  required => 1,
);

has log => (
  is      => 'ro',
  isa     => InstanceOf['ZeroBot::Log'],
  builder => sub {
    my $self = shift;
    ZeroBot::Log->new(level => $self->cfg->core->{Logging}->{Level})
  },
);

has modules => (
  is      => 'rwp',
  isa     => HashRef[InstanceOf['ZeroBot::Module::File']],
  default => sub { {} },
);

has cmdchar => (
  is      => 'rwp',
  isa     => sub { length($_[0]) == 1 },
  lazy    => 1,
  builder => sub {
    my $self = shift;
    $self->cfg->core->{CmdChar};
  },
);

sub init
{
  my $self = shift;

  # TODO: Load core-related config, set up DBI (load actual db here or elsewhere?), etc

  # Set up Core logger
  my %writers = (stdout => {type => 'Term'});
  if ($self->cfg->core->{Logging}->{Enabled})
  {
    $writers{file} = {
      type => 'File',
      filepath => 'logs/' . $self->cfg->core->{Logging}->{File},
    };
  }
  $self->log->add_writers(%writers);
  $self->log->level($self->cfg->core->{Logging}->{Level});

  $self->log->info("Starting ZeroBot, version $VERSION");

  # Initialize Syndicator
  $self->log->verbose('Initializing Core syndicator');
  $self->_syndicator_init(
    prefix        => 'ZBCore_',
    reg_prefix    => 'Module_',
    types         => [ SERVER => 'Bot', USER => 'Out' ], # FIXME: change as necessary
    debug         => 1,
    object_states => [
      $self => [qw(
        syndicator_started
        syndicator_stopped
        shutdown
        sig_HUP

        ZBCore_plugin_error
      )],
    ],
  );
}

sub syndicator_started
{
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  $self->log->debug('Core syndicator started');

  # Register signal handlers
  $kernel->sig(INT  => 'shutdown');
  $kernel->sig(TERM => 'shutdown');
  $kernel->sig(HUP  => 'sig_HUP');
  #$kernel->sig(USR1  => 'sig_USR1');
  #$kernel->sig(USR2  => 'sig_USR2');

  # Set session alias for Syndicator
  $kernel->alias_set('ZBCore');

  # Load Protocol Modules
  $self->add_protocol($_) for (@{$self->cfg->core->{Protocols}});

  # Load Feature Modules
  foreach my $module (@{$self->cfg->modules->{Enabled}})
  {
    if (module_is_available($module))
    {
      $self->log->warning("Module '$module' already loaded, check your config for duplicates!")
        if module_is_loaded($module);

      $self->log->verbose("Loading module: $module");
      module_load($module);
    }
    else
    {
      $self->log->warning("Module not found: $module");
      # TBD: Send an event for this
    }
  }
}

sub syndicator_stopped
{
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  $self->log->debug('Core syndicator stopping...');

  # TODO: Move this somewhere appropriate. Is there an event we can catch in the
  # protocol modules when the syndicator is dying (syndicator_shutdown)?
  # Maybe shutdown() can send some kind of shutdown event that protocols catch
  # TODO: pull quit message from somewhere (or will they already be
  # disconnected at this point?)
  # Shut down all PoCo::IRC sessions
  # $self->log->debug('Shutting down IRC connections');
  # $kernel->signal($kernel, 'POCOIRC_SHUTDOWN');

  $self->log->debug('Core syndicator stopped')
}

sub shutdown
{
  my $self = $_[OBJECT];

  # TODO ...

  $self->log->info('Core shutting down...');

  # Handles cleaning up after the syndicator, such as unregistering and
  # destroying plugins and making sure the Session doesn't stick around
  $self->_syndicator_destroy();
}

sub sig_HUP
{
  ...
}

sub ZBCore_plugin_error
{
  my ($self, $err) = @_[OBJECT, ARG0];

  # TODO ...

  CORE::say "Plugin error: $err";
}

sub add_protocol
{
  my ($self, $proto) = @_;
  $self->log->info("Loading $proto protocol");

  try
  {
    no strict 'refs';
    require "ZeroBot/$proto.pm";
    $self->plugin_add('Proto_IRC', "ZeroBot::$proto"->new());
  }
  catch { $self->log->error("Failed to load $proto protocol: $_") };
}

1;
