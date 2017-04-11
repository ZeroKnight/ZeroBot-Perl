package ZeroBot::IRC;

our $VERSION = "0.005";
$VERSION = eval $VERSION;

use ZeroBot::Common;
use ZeroBot::Module -all;
use ZeroBot::IRC::Network;
use ZeroBot::IRC::Server;
use ZeroBot::IRC::Message;

use Moo;
use Types::Standard qw(HashRef InstanceOf);

# use IRC::Utils qw(...);
use POE qw(
  Component::IRC::State
  Component::IRC::Plugin::Connector
);

has networks => (
  is  => 'rw',
  isa => HashRef[InstanceOf['ZeroBot::IRC::Network']],
  init_arg => undef,
  default => sub{ {} },
);

sub Module_register
{
  my $self = shift;

  # TODO: Logging

  module_register($self, 'SERVER', 'all');
  $self->_initialize_irc;
  return MODULE_EAT_NONE;
}

sub _initialize_irc
{
  my $self = shift;

  # TODO: Proper logging
  CORE::say 'Initializing IRC Module';

  my $irc_cfg = ZBCORE->cfg->irc;
  my ($available, $autoconnected);
  foreach my $network (keys %{$irc_cfg->{Networks}})
  {
    my $nethash = $irc_cfg->{Networks}{$network};

    # Create Server object(s)
    my @servers;
    foreach my $server (@{$nethash->{Servers}})
    {
      unless ($server->{Hostname})
      {
        # TODO: proper logging
        CORE::say "Server defined in $network has no Hostname, trying next.";
        next;
      }

      # Fall back to constructor defaults if needed
      my %server_opts = (hostname => $server->{Hostname});
      $server_opts{port}     = $server->{Port} if defined $server->{Port};
      $server_opts{password} = $server->{Password} if defined $server->{Password};
      $server_opts{ssl}      = $server->{UseSSL} if defined $server->{UseSSL};
      $server_opts{ipv6}     = $server->{UseIPv6} if defined $server->{UseIPv6};

      push @servers, ZeroBot::IRC::Server->new(%server_opts);
    }
    unless (@servers)
    {
      # TODO: Proper logging
      CORE::say "Network $network does not have any servers defined! Ignoring.";
      next;
    }

    # Create Network object
    my %network_opts = (
      name     => $network,
      servers  => [@servers],
      channels => [ @{$nethash->{Channels}} ],
    );

    # Fall back to constructor defaults if needed
    my $nick  = $nethash->{Nick}  // $irc_cfg->{Identity}{Nick};
    my $user  = $nethash->{User}  // $irc_cfg->{Identity}{User};
    my $gecos = $nethash->{Gecos} // $irc_cfg->{Identity}{Gecos};
    $network_opts{nick}  = $nick if defined $nick;
    $network_opts{user}  = $user if defined $user;
    $network_opts{gecos} = $gecos if defined $gecos;
    $network_opts{umode} = $nethash->{UMode} if defined $nethash->{UMode};

    $self->networks->{$network} = ZeroBot::IRC::Network->new(%network_opts);

    # Connect any Networks set to AutoConnect
    if ($irc_cfg->{Networks}{$network}{AutoConnect})
    {
      ++$autoconnected;
      module_send_event(irc_connect_network => $network);
    }
    ++$available;
  }
  # TODO: proper logging
  CORE::say "Initialized $available Networks, $autoconnected auto-connecting";
}

sub Bot_irc_connect_network
{
  my ($self, $core) = splice @_, 0, 2;
  my $network = ${ $_[0] };

  my $network_obj = $self->networks->{$network};
  unless (defined $network_obj)
  {
    # TODO: Proper logging
    CORE::say "Attempted to connect unknown Network $network";
    return MODULE_EAT_ALL;
  }

  # TODO: Check to see if the given network is already connected. If so,
  # irc->quit with a 'Reconnecting' message and irc->connect again

  # TODO: Implement rotating to other defined servers (if specified) if the
  # first choice fails

  # TODO: proper logging
  my $hostname = $network_obj->servers->[0]->hostname;
  my $port = $network_obj->servers->[0]->port;
  CORE::say "Spawning IRC connection for Network $network, Server $hostname on port $port";

  my %spawn_opts = (
    alias      => "IRC_$network",
    Server     => $network_obj->servers->[0]->hostname,
    Port       => $network_obj->servers->[0]->port,
    Password   => $network_obj->servers->[0]->password,
    Nick       => $network_obj->nick,
    Username   => $network_obj->user,
    Ircname    => $network_obj->gecos,
    # Bitmode => ...,
    # UseSSL, SSLCert, SSLKey, SSLCtx ...
    useipv6    => $network_obj->servers->[0]->ipv6 // 0,
    Flood      => 1, # PoCo::IRC's anti-flood is overly cautious
    # We implement message splitting, so override PoCo IRC's default of 450.
    # NOTE: PoCo IRC will still subtract nick length from this, however.
    msg_length => 512,
  );
  $spawn_opts{LocalAddr} = ZBCORE->cfg->core->{BindAddr}
    if defined ZBCORE->cfg->core->{BindAddr};

  # TODO: proper logging
  my $irc = POE::Component::IRC::State->spawn(%spawn_opts)
    or CORE::say "Failed to spawn() IRC component for Network $network"
    and return MODULE_EAT_ALL;
  $network_obj->set_irc($irc);

  # Create POE::Session for IRC Component
  $self->_create_network_session($network);
  # TODO: debug log success here

  return MODULE_EAT_ALL;
}

sub _create_network_session
{
  my ($self, $network) = @_;

  # TODO: Logging and error check for create()

  # Create a session and assign callbacks to handle the IRC messages/events
  # Store the corresponding Network name in the heap
  POE::Session->create(
    heap => { Network => $network, irc => $self->networks->{$network}->irc },
    object_states => [
      $self => [qw(
        _start
        _stop
        irc_error
        irc_connected
        irc_join
        irc_nick
      )],
      $self => {
        _default => 'irc_default',
        irc_001  => 'irc_welcome',
        irc_433  => 'irc_nickname_in_use',
      },
    ],
    # Inlining these prevents requiring 4 nearly-identical subs or a bunch of
    # wrapper subs feeding irc_spoke
    # inline_states => {
    #   irc_public      => sub { $self->irc_spoke(MSGTYPE_PUBLIC,  @_) },
    #   irc_msg         => sub { $self->irc_spoke(MSGTYPE_PRIVATE, @_) },
    #   irc_notice      => sub { $self->irc_spoke(MSGTYPE_NOTICE,  @_) },
    #   irc_ctcp_action => sub { $self->irc_spoke(MSGTYPE_ACTION,  @_) },
    # },
  ) or die "Failed to create IRC component session for Network $network";
  # TODO: proper logging
}

sub _stop { ... }
sub irc_error { ... }
sub irc_join { ... }
sub irc_nick { ... }

sub _start
{
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my $network = $heap->{Network};
  my $irc = $heap->{irc};

  # NOTE: Can register signals here (eg. DIE)

  # TODO: Use POE::Component::IRC::Plugin::Proxy for our connection to allow
  # for seamless restarts and on-the-fly changes

  # TODO: Load any other PoCo::IRC plugins here

  # NOTE: Set an alias?

  # Connector handles automatic reconnection to an IRC server
  # $self->_ircobj->plugin_add(
  #   Connector => POE::Component::IRC::Plugin::Connector->new()
  # );

  # Register for all messages/events, falling back to _default() if there is
  # no explicitly assigned callback
  $irc->yield(register => 'all');

  # ...and connect!
  $irc->yield(connect => {});
}

sub irc_connected
{
  my ($self, $server) = @_[OBJECT, ARG0];

  # TODO: proper logging (debug? or info?)
  CORE::say "Established connection to $server, now registering...";
}

sub irc_welcome
{
  # 001 RPL_WELCOME
  my ($self, $heap) = @_[OBJECT, HEAP];
  my $network = $heap->{Network};
  my $irc = $heap->{irc};

  # TODO: proper logging
  my $server = $irc->server_name;
  CORE::say "Network $network: Successfully connected to $server";

  # Join configured channels
  foreach my $channel (@{$self->networks->{$network}->channels})
  {
    CORE::say "Joining $channel";
    $irc->yield(join => $channel);
  }
}

sub irc_nickname_in_use
{
  # 443 ERR_NICKNAMEINUSE
  my ($self, $heap) = @_[OBJECT, HEAP];
  my $network = $heap->{Network};
  my $network_obj = $self->networks->{$network};
  my $irc = $heap->{irc};

  # TODO: proper logging
  CORE::say "Nick '" . $network_obj->nick . "' already in use.";
  $network_obj->nick($network_obj->nick . '_');
  $irc->yield(nick => $network_obj->nick);
}

sub irc_default
{
  my ($event, $args) = @_[ARG0 .. $#_];
  my @output = ("$event: ");

  for my $arg (@$args) {
    if (ref $arg eq 'ARRAY') {
      push(@output, '[' . join(', ', @$arg) . ']');
    }
    else {
      push(@output, "'$arg'");
    }
  }
  CORE::say "@output";
  return;
}

1;

__END__
##### OLD SHIT

sub irc_spoke
{
  # Handles PRIVMSGs, NOTICEs and ACTIONs
  my ($self, $msgtype) = (shift, shift);
  my ($who, $where, $what) = @_[ARG0 .. ARG2];
  my ($nick, $user, $host) = (split /[!@]/, $who);
  my $cmdchar = $self->CmdChar;

  # Store message info
  my $msg = {
    nick  => $nick,
    user  => $user,
    host  => $host,
    where => $msgtype eq 'msg' ? $nick : $where->[0],
    body  => $what,
  };

  # Are we being issued a command?
  if ($msgtype ne 'action' and $what =~ /^$cmdchar/) {
    $self->_parse_command($what);
    my @arg = @{ $self->_cmdhash->{arg} };

    # Looking for help...
    if ($self->_cmdhash->{name} eq 'help') {
      my @modules = $self->module_list(', ');
      unless ($arg[0]) {
        $self->reply($msg->{where}, $msg->{nick},
          "Specify a module to see help for. Loaded modules: @modules"
        );
        return;
      }
      # Is the requested module loaded?
      my $search = (grep { $arg[0] =~ /$_/i } keys $self->Modules)[0];
      if ($search) {
        $self->notice($nick => $_) for $self->Modules->{$search}->help();
        return;
      } else {
        $self->reply($msg->{where}, $msg->{nick},
          "No module named '$arg[0]' is loaded. Loaded modules: @modules"
        );
        return;
      }
    } else { # Command issued
      my $rv;
      foreach my $module (values $self->Modules) {
        next unless $module->can('commanded');
        $rv = $module->commanded($msg, $self->_cmdhash);
        last if $rv;
      }
      unless ($rv) {
        if (exists $self->Modules->{BadCmd}) {
          $self->Modules->{BadCmd}->badcmd($msg->{where});
        } else {
          $self->reply($msg->{where}, $msg->{nick}, 'No such command.');
        }
      }
    }
  } else { # No command, just chatter
    foreach my $module (values $self->Modules) {
      if ($msgtype eq 'channel' or $msgtype eq 'msg') {
        next unless $module->can('said');
        $module->said($msg);
      } elsif ($msgtype eq 'action') {
        next unless $module->can('emoted');
        $module->emoted($msg);
      } elsif ($msgtype eq 'notice') {
        next unless $module->can('noticed');
        $module->noticed($msg);
      }
    }
  }
}

sub irc_join
{
  my ($self, $who, $where) = @_[OBJECT, ARG0, ARG1];
  my $irc = $self->_ircobj;
  my $nick = (split /!/, $who)[0];

  # XXX: Get our User/Hostname (PoCoIRC should have a function for this...)
  # TODO: Update this when our user/hostname changes (vhost, etc)
  if ($nick eq $self->Nick) {
    $self->User((split /!/, $who)[1]); # in case the server mangled it (freenode)
    $self->Hostname((split /@/, $who)[1]);
  }

  foreach my $module (values $self->Modules) {
    next unless $module->can('joined');
    $module->joined($nick, $where);
  }
  return;
}

sub irc_nick
{
  my ($self, $who, $newnick) = @_[OBJECT, ARG0, ARG1];

  $self->Nick($newnick) if (split /!/, $who)[0] eq $self->Nick;
}

sub irc_stop
{
  return;
}

sub irc_error
{
  return;
}
