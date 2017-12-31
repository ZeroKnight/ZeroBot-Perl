package ZeroBot::Core;

use strictures 2;
our $VERSION = '0.005';
$VERSION = eval $VERSION;

use ZeroBot::Config;
use ZeroBot::Log;
use ZeroBot::Database;
use ZeroBot::Module -all;

use POE;
use Path::Tiny;
use Try::Tiny;
use Text::Pluralize;

use Moo;
use Types::Standard qw(HashRef InstanceOf);
use Types::Path::Tiny qw(Path);
with 'MooX::Singleton';

# PoCo::Syndicator comprises the heart of ZeroBot's module (plugin) system
extends 'POE::Component::Syndicator';

has cfg_dir => (
  is  => 'ro',
  isa => Path,
  coerce => 1,
  default => sub { path('config') },
);

has cfg => (
  is       => 'rwp',
  isa      => InstanceOf['ZeroBot::Config'],
  lazy     => 1,
  builder  => sub {
    my $self = shift;
    ZeroBot::Config->new($self->cfg_dir->stringify);
  },
);

has log => (
  is      => 'ro',
  isa     => InstanceOf['ZeroBot::Log'],
  lazy    => 1,
  builder => sub {
    my $self = shift;
    my $level = $self->cfg->core->{Logging}{Level};
    ZeroBot::Log->new(defined $level ? (level => $level) : ());
  },
);

has db => (
  is       => 'rwp',
  isa      => InstanceOf['ZeroBot::Database'],
  lazy     => 1,
  init_arg => undef,
);

has modules => (
  is      => 'rwp',
  isa     => HashRef[InstanceOf['ZeroBot::Module::File']],
  default => sub { +{} },
);

has cmdchar => (
  is      => 'rwp',
  isa     => sub { length($_[0]) == 1 },
  lazy    => 1,
  builder => sub {
    my $self = shift;
    $self->cfg->core->{Core}{CmdChar} // '!';
  },
);

sub BUILD
{
  my $self = shift;

  # Run builders
  $self->cfg;
  $self->log;
}

sub init
{
  my $self = shift;

  # Set up Core logger
  my %writers = (stdout => {type => 'Term'});
  if ($self->cfg->core->{Logging}{Enabled})
  {
    $writers{file} = {
      type => 'File',
      filepath => 'logs/' . $self->cfg->core->{Logging}{File},
    };
  }
  $self->log->add_writers(%writers);

  # Initialize Database
  my %db_opts = (
    filepath        => $self->cfg->core->{Database}{File} // 'ZeroBot.sqlite',
    user            => $self->cfg->core->{Database}{User} // '',
    password        => $self->cfg->core->{Database}{Password} // '',
    backups_enabled => $self->cfg->core->{Database}{Backup}{Enabled} // 1,
  );
  $self->log->info('Initializing Database');
  $self->_set_db(ZeroBot::Database->new(%db_opts));

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
  my $protos_loaded = 0;
  my @protos = $self->cfg->get_as_list($self->cfg->core->{Core}{Protocols});
  unless (@protos)
  {
    $self->log->fatal('No protocol modules enabled! At least one protocol must be enabled.');
    $kernel->call($_[SESSION], 'shutdown');
    return;
  }
  foreach my $p (@protos)
  {
    ++$protos_loaded if $self->add_protocol($p);
  }
  if ($protos_loaded == 0)
  {
    $self->log->fatal('Failed to load any protocol modules! At least one protocol must load successfully.');
    $kernel->call($_[SESSION], 'shutdown');
    return;
  }
  $self->log->info(pluralize("Loaded %d protocol(s)", $protos_loaded));

  # Load Feature Modules
  my $modules_loaded = 0;
  my @modules = $self->cfg->get_as_list($self->cfg->modules->{Modules}{Enabled});
  foreach my $module (@modules)
  {
    if (module_is_available($module))
    {
      $self->log->warning("Module '$module' already loaded, check your config for duplicates!")
        if module_is_loaded($module);

      $self->log->verbose("Loading module: $module");
      ++$modules_loaded if module_load($module);
    }
    else
    {
      $self->log->warning("Module not found: $module");
      # TBD: Send an event for this
    }
  }
  $self->log->info(pluralize("Loaded %d module(s)", $modules_loaded));
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

  $self->cfg->add_protocol_config($proto) or return;
  my $success = try {
    no strict 'refs';
    require "ZeroBot/$proto.pm";
    return $self->plugin_add("Proto_$proto", "ZeroBot::$proto"->new());
  }
  catch
  {
    $self->log->error("Failed to load $proto protocol: $_");
    return;
  };
  return unless $success;
  return 1;
}

1;
