package ZeroBot::Core;

use strictures 2;
our $VERSION = '0.005';
$VERSION = eval $VERSION;

use ZeroBot::Config;
use ZeroBot::Log;

use Carp;
use Try::Tiny;

use POE;
# use Math::Random::MT;
# use Storable qw(dclone);
# use Text::Wrap ();

use Moo;
use Types::Standard qw(InstanceOf);
with 'MooX::Singleton';

# PoCo::Syndicator comprises the heart of ZeroBot's module (plugin) system
extends 'POE::Component::Syndicator';

has cfg => (
  is       => 'rw',
  isa      => InstanceOf['ZeroBot::Config'],
  required => 1,
);

has log => (
  is  => 'ro',
  isa => InstanceOf['ZeroBot::Log'],
  builder => sub {
    my $self = shift;
    ZeroBot::Log->new(level => $self->cfg->core->{Logging}->{Level})
  },
);

has cmdchar => (
  is  => 'rwp',
  isa => sub { length($_[0]) == 1 },
  lazy => 1,
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
  $self->log->add_writers(
    stdout => { type => 'Term' },
    # TODO: add file writer if cfg->core->{Logging}->{Enabled} is true
  );
  # $self->log->level($self->cfg->core->{Logging}->{Level});

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

  # TODO: Initialize and load modules
  # XXX: temp shit just to figure this all out
  # Wrap this up in module_load()
  print "loading IRC plugin\n";
  require 'ZeroBot/IRC.pm';
  my $obj = ZeroBot::IRC->new();

  $self->plugin_add('IRC', $obj); # <<< this ends up calling *_register !!
}

sub syndicator_stopped
{
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  $self->log->debug('Core syndicator stopping...');

  # TODO: pull quit message from somewhere (or will they already be
  # disconnected at this point?)
  # Shut down all PoCo::IRC sessions
  $self->log->debug('Shutting down IRC connections');
  $kernel->signal($kernel, 'POCOIRC_SHUTDOWN');

  $self->log->debug('Core syndicator stopped')
}

sub shutdown
{
  my $self = $_[OBJECT];

  # TODO ...

  $self->log->warning('Core shutting down...');

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

1;

__END__
### OLD

sub privmsg {
  my ($self, $target, $body) = @_;

  $self->speak(privmsg => $target, $body);
}

sub notice {
  my ($self, $target, $body) = @_;

  $self->speak(notice => $target, $body);
}

sub emote {
  my ($self, $target, $action) = @_;

  # Make sure we have a destination and something to send
  if (!defined $target or !defined $action) {
    carp "emote: Can't send an action without a target and body";
    return;
  }

  $self->_ircobj->yield(ctcp => $target, "ACTION $action");
}

sub reply {
  my ($self, $target, $who, $body) = @_;

  $self->privmsg($target, ($target ne $who ? "$who: " : '') . $body);
}

sub joinchan {
  my ($self, $channel, $key) = @_;

  $self->_ircobj->yield(join => $channel, $key);
}

sub kick {
  my ($self, $channel, $who, $reason) = @_;

  $self->_ircobj->yield(kick => $channel, $who, $reason);
}

sub ischanop {
  my $self = shift;

  return $self->_ircobj->is_channel_operator(shift);
}
