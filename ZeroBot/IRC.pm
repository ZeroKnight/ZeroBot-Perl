package ZeroBot::IRC;

our $VERSION = "0.005";
$VERSION = eval $VERSION;

use ZeroBot::Common;
use ZeroBot::Module -all;
use ZeroBot::IRC::Network;
use ZeroBot::IRC::Server;
use ZeroBot::IRC::Message;
use ZeroBot::IRC::Command;

use IRC::Utils ':ALL';
use POE qw(
  Component::IRC::State
  Component::IRC::Plugin::Connector
);

use Moo;
use Types::Standard qw(HashRef InstanceOf);

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
  my ($available, $autoconnecting);
  foreach my $network (keys %{$irc_cfg->{Networks}})
  {
    my $nethash = $irc_cfg->{Networks}{$network};

    # Create ZeroBot::IRC::Server object(s)
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

    # Create ZeroBot::IRC::Network object
    my %network_opts = (
      name     => $network,
      servers  => [@servers],
      channels => [ @{$nethash->{Channels}} ],
    );

    # Fall back to main Identity, or even a hard default if needed
    my $nick  = $nethash->{Nick}  // $irc_cfg->{Identity}{Nick}  // 'ZeroBot';
    my $user  = $nethash->{User}  // $irc_cfg->{Identity}{User}  // 'zerobot';
    my $gecos = $nethash->{Gecos} // $irc_cfg->{Identity}{Gecos} // "ZeroBot v$VERSION";

    # Fall back to constructor defaults if needed
    $network_opts{nick}  = $nick if defined $nick;
    $network_opts{user}  = $user if defined $user;
    $network_opts{gecos} = $gecos if defined $gecos;
    $network_opts{umode} = $nethash->{UMode} if defined $nethash->{UMode};

    $self->networks->{$network} = ZeroBot::IRC::Network->new(%network_opts);

    # Connect any Networks set to AutoConnect
    if ($irc_cfg->{Networks}{$network}{AutoConnect})
    {
      ++$autoconnecting;

      # Actual connection is dispatched, so that POE can handle it like any
      # other event, and so that initialization is separate from connection,
      # which enables modules to reconnect a given network.
      module_send_event(irc_connect_network => $network);
    }
    ++$available;
  }
  # TODO: proper logging
  CORE::say "Initialized $available Networks, $autoconnecting auto-connecting";
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
  $self->_create_network_session($network_obj);
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
    heap => { network => $network, irc => $network->irc },
    object_states => [
      $self => [qw(
        _start
        _stop
        irc_error
        irc_connected
        irc_disconnected

        irc_join
        irc_nick

        irc_302
      )],
      $self => {
        _default => 'irc_default',
        irc_001  => 'irc_welcome',
        irc_432  => 'irc_erroneous_nickname',
        irc_433  => 'irc_nickname_in_use',
      },
    ],
    # Inlining these prevents requiring 4 nearly-identical subs or a bunch of
    # wrapper subs feeding irc_spoke
    inline_states => {
      irc_public      => sub { $self->irc_spoke(MSGTYPE_PUBLIC,  @_) },
      irc_msg         => sub { $self->irc_spoke(MSGTYPE_PRIVATE, @_) },
      irc_notice      => sub { $self->irc_spoke(MSGTYPE_NOTICE,  @_) },
      irc_ctcp_action => sub { $self->irc_spoke(MSGTYPE_ACTION,  @_) },
    },
  ) or die 'Failed to create IRC component session for Network '.$network->name."\n";
  # TODO: proper logging
}

sub _start
{
  my ($self, $kernel, $heap) = @_[OBJECT, KERNEL, HEAP];
  my ($network, $irc) = @{$heap}{'network', 'irc'};

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

sub _stop
{
  # TODO: not sure what we'll do here yet, but probably try to gracefully close
  # any running IRC sessions (if they still exist at this point), and any other
  # related cleanup
  ...
}

sub irc_connected
{
  my ($self, $heap, $server) = @_[OBJECT, HEAP, ARG0];
  my $network = $heap->{network};
  my $netname = $network->name;

  # TODO: proper logging (debug? or info?)
  CORE::say "[$netname] Established connection to $server, now registering...";
}

sub irc_disconnected
{
  my ($self, $heap, $server) = @_[OBJECT, HEAP, ARG0];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $netname = $network->name;

  # TODO: proper logging
  CORE::say "[$netname] Disconnected from $server";

  $network->_set_connected(0);
  module_send_event(disconnected => $network, $server);
}

sub irc_welcome
{
  # 001 RPL_WELCOME
  my ($self, $heap) = @_[OBJECT, HEAP];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $netname = $network->name;

  # TODO: proper logging
  my $server = $irc->server_name;
  CORE::say "Network $netname: Successfully connected to $server";
  $network->_set_connected(1);
  $network->_set_connected_at(time);

  # Request our Username and Host from the server, as it may have mangled our
  # Username (Freenode prefixing '~' on non-ident clients), or a cloak may have
  # been applied over our Host (umode +x or otherwise).
  $irc->yield(userhost => $network->nick);

  # TODO: send 'connected' event
  # module_send_event(connected => ...);

  # Join configured channels
  foreach my $channel (@{$network->channels})
  {
    CORE::say "[$netname] Joining $channel";
    $irc->yield(join => $channel);
  }
}

sub irc_join
{
  my ($self, $heap, $who, $channel) = @_[OBJECT, HEAP, ARG0, ARG1];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $nick = parse_user($who);

  # TODO: send 'join' event
  # module_send_event(join => ...);
}

sub irc_nick
{
  my ($self, $heap, $who, $newnick, $common) = @_[OBJECT, HEAP, ARG0 .. ARG2];
  my ($network, $irc) = @{$heap}{'network', 'irc'};

  $network->_set_nick($newnick) if parse_user($who) eq $irc->nick_name; # XXX: temp

  # TODO: send nick event to modules
  # module_send_event(nick_change => data...);
}

sub irc_spoke
{
  my ($self, $msgtype) = splice @_, 0, 2;
  my ($heap, $src, $dests, $body) = @_[HEAP, ARG0 .. ARG2];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $cmdchar = ZBCORE->cmdchar;

  # Determine whether this is a plain message, or a command
  if ($msgtype < MSGTYPE_NOTICE and $body =~ /^$cmdchar/)
  {
    # module_send_event(commanded => $body);
    # ...
    # XXX: temp test
    my $cmd = ZeroBot::Command->new(
      line => $body,
      spec => {
        test => {
          'h|help|fuck' => OPTVAL_NONE,
          'f|foo' => OPTVAL_NONE,
          'b|bar|barr' => OPTVAL_REQUIRED,
          'l|log' => OPTVAL_OPTIONAL,
        }
      }
    );
    {
      no warnings;
      my @m = ('Name:', $cmd->name, 'Args:', @{$cmd->args}, 'Opts:', %{$cmd->opts});
      $irc->yield(privmsg => $dests->[0], "@m");
    }
  }
  else
  {
    use feature 'switch';
    no warnings 'experimental::smartmatch';
    my $msg = ZeroBot::IRC::Message->new(
      network => $network,
      src     => $src,
      dests   => $dests,
      type    => $msgtype,
      message => $body,
    );
    # for ($msgtype)
    # {
    #   module_send_event(public  => $msg) when MSGTYPE_PUBLIC;
    #   module_send_event(private => $msg) when MSGTYPE_PRIVATE;
    #   module_send_event(notice  => $msg) when MSGTYPE_NOTICE;
    #   module_send_event(action  => $msg) when MSGTYPE_ACTION;
    # }
    # ...
  }
}

sub irc_302
{
  # 302 RPL_USERHOST
  my ($self, $heap, $rpl) = @_[OBJECT, HEAP, ARG1];
  my ($network, $irc) = @{$heap}{'network', 'irc'};

  # NOTE: The '+' or '-' indicates away state; '-' means away.
  my ($nick, $user, $host) = $rpl =~ /([^=]+)=[+-]([^@]+)@(\S+)/;

  # Keep our user/host attributes in sync
  if ($nick eq $network->nick)
  {
    $network->_set_user($user);
    $network->_set_host($host);
  }
}

### Error events ###############################################

sub irc_error
{
  my ($self, $heap, $errmsg) = @_[OBJECT, HEAP, ARG0];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $netname = $network->name;

  # TODO: proper logging
  CORE::say "Network $netname error: $errmsg";
  module_send_event(server_error => $errmsg);
}

sub irc_erroneous_nickname
{
  # 432 ERR_ERRONEUSNICKNAME
  my ($self, $heap, $err) = @_[OBJECT, HEAP, ARG2];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $badnick = $err->[0];
  my $netname = $network->name;

  # TODO: proper logging
  CORE::say "[$netname] Erroneous Nickname: $badnick";

  # Let any intersted modules handle this event
  # NOTE: Not sure yet how we'll handle this event return here
  my $eat = module_send_event(nick_erroneous => $badnick);
  return if $eat == MODULE_EAT_ALL;

  my $nicklen = $irc->isupport('NICKLEN');
  if (defined $nicklen and length $badnick > $nicklen)
  {
    # TODO: proper logging (debug?)
    CORE::say "[$netname] Truncating nick to fit NICKLEN";
    $irc->yield(nick => substr($badnick, 0, $nicklen));
  }
  else
  {
    # If we're in the registration phase with a bad nick, disconnect and let the
    # user correct it. Otherwise this nick change attempt was likely from some
    # bot event and we can just ignore it and move on.
    if (!$network->connected)
    {
      # TODO: proper logging
      CORE::say "[$netname] Cannot register connection with erroneous nickname; disconnecting.";
      $irc->disconnect;
    }
  }
}

# TODO: handle 437 (unavailable resource)
sub irc_nickname_in_use
{
  # 433 ERR_NICKNAMEINUSE
  my ($self, $heap) = @_[OBJECT, HEAP];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $nick = $network->nick;
  my $netname = $network->name;

  # TODO: proper logging
  CORE::say "[$netname] Nick '$nick' already in use.";

  # If we're in the registration phase, this event is either due to a ghosted
  # connection with this nick, or the nick is has been stolen (or perhaps the
  # other way around ;)) For now, do what we can to register and let any
  # interested modules take over.
  if (!$network->connected)
  {
    my $newnick;
    if ($nick =~ /__$/) # Don't get crazy with the underscores
    {
      $newnick = substr $nick, 0, -1;
      $newnick .= '1';
    }
    elsif ($nick =~ /_(\d)$/)
    {
      $newnick = substr $nick, 0, -1;
      $newnick .= $1 + 1;
    }
    else
    {
      $newnick = "${nick}_";
    }
    $network->_set_nick($newnick);
    $irc->yield(nick => $newnick);
  }
  module_send_event(nick_in_use => $nick);
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

