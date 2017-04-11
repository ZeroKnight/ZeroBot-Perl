package ZeroBot::Core;

use strictures 2;
our $VERSION = '0.005';
$VERSION = eval $VERSION;

use ZeroBot::Config;

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

has cmdchar => (
  is  => 'rwp',
  isa => sub { length($_) == 1 },
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

  # Initialize Syndicator
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

  ## NOTE: Make a flow chart for this shit. super confusing
}

sub syndicator_stopped
{
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  CORE::say 'syndicator_stopped';
  # TODO: (Debug?) Log that core syndicator is stopping

  # TODO: (Debug?) Log that POCOIRC objects will now be shutdown
  # TODO: pull quit message from somewhere (or will they already be
  # disconnected at this point?

  # Shut down all PoCo::IRC sessions
  $kernel->signal($kernel, 'POCOIRC_SHUTDOWN');

  # TODO: (Debug?) Log that core syndicator has stopped
}

sub shutdown
{
  my $self = $_[OBJECT];

  # TODO ...

  CORE::say 'shutdown';
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

sub _parse_command {
  my $self = shift;
  my ($lastarg, $need_optval, @opt, @val);
  my $parse_opts = 1;
  my $cmdhash = {
    name => undef,
    opt => {},
    arg => []
  };

  foreach my $arg (split /\s+/, shift) {
    if ($need_optval) {
      if ($arg =~ /"$/) { # End of value; add to hash
        push @val, $arg =~ tr/"//dr;
        $cmdhash->{opt}{$opt[0]} = join(' ', @val);
        $need_optval = 0;
        @opt = (); @val = ();
      } else { # Still part of value
        push @val, $arg;
      }
    } else {
      my $cmdchar = $self->CmdChar;
      if ($parse_opts and $arg =~ /^$cmdchar\w+/) {
        # Command Name
        $cmdhash->{name} = eval "\$arg =~ tr/$cmdchar//dr";
      } elsif ($parse_opts and $arg =~ /^--/) {
        # Marker to stop processing options and
        # treat everything else as arguments
        $parse_opts = 0;
      } elsif ($parse_opts and $arg =~ /^-\w+=/) {
        # Option with value
        $arg =~ tr/-//d;
        @opt = split('=', $arg);
        if ($opt[1] =~ /^"/) { # Value consists of multiple args
          push @val, $opt[1] =~ tr/"//dr;
          $need_optval = 1;
        } else {
          $cmdhash->{opt}{$opt[0]} = $opt[1];
        }
      } elsif ($parse_opts and $arg =~ /^-\w+/) {
        # Option with no value
        $arg =~ tr/-//d;
        $cmdhash->{opt}{$arg} = undef;
      } else {
        # We've hit arguments, stop parsing options (and name)
        $parse_opts = 0 if $parse_opts;
        push $cmdhash->{arg}, $arg;
      }
    }
  }
  $self->_cmdhash($cmdhash);
}

sub _compress_arg {
  # Compress quoted args into one. Takes an array reference
  my ($self, $start, $args) = @_;

  return unless ref $args eq 'ARRAY';

  unless (@$args == 1) {
    my $index = $start;
    $index++ until $args->[$index] =~ /"$/;
    splice @$args, $start, $index+1, "@$args[$start .. $index]";
  }
  $args->[$start] =~ tr/"//d;
}

sub speak {
  my ($self, $msgtype, $target, $body) = @_;

  unless ($msgtype eq 'privmsg' or $msgtype eq 'notice') {
    carp "speak: Message type must be either 'privmsg' or 'notice'";
    return;
  }

  # Make sure we have a destination and something to send
  if (!defined $target or !defined $body) {
    carp "speak: Can't send a " . uc($msgtype) . ' without a target and body';
    return;
  }

  # Figure out how long our message body can be. 512 characters maximum for
  # messages, with 2 always being the CR-LF pair; the prefix, command and
  # destination, and the 3 spaces and 2 colons separating the arguments
  my $msg = ":$self->Bot->Nick!$self->Bot->User\@$self->Bot->Hostname $msgtype $target :";
  my $maxlen = 510 - (length $msg);

  # XXX: do we really need Text::Wrap for this single use case?
  # Split up long messages if needed
  if (length $body > $maxlen) {
    local $Text::Wrap::columns = $maxlen;
    my @wrapped = split /\n+/, Text::Wrap::wrap('', '', $body);

    foreach my $chunk (@wrapped) {
      $self->_ircobj->yield($msgtype, $target, $chunk);
    }
  } else {
    $self->_ircobj->yield($msgtype, $target, $body);
  }
}

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
