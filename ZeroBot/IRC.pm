package ZeroBot::IRC;

our $VERSION = "0.005";
$VERSION = eval $VERSION;

use ZeroBot::Common -types, -string;
use ZeroBot::Module -std;
use ZeroBot::Module::Loader -load;

use ZeroBot::IRC::Network;
use ZeroBot::IRC::Server;
use ZeroBot::IRC::User;
use ZeroBot::IRC::ServerReply;
use ZeroBot::IRC::Event::Message;
use ZeroBot::IRC::Event::Command;
use ZeroBot::IRC::Event::Join;
use ZeroBot::IRC::Event::Kick;
use ZeroBot::IRC::Event::Nick;

use Encode qw(encode_utf8);
use IRC::Utils ':ALL';
use POE qw(
  Component::IRC::State
  Component::IRC::Plugin::Connector
);

use Carp;
use Moose;
use MooseX::AttributeShortcuts;

has networks => (
  is       => 'rw',
  isa      => HashRef[InstanceOf['ZeroBot::IRC::Network']],
  init_arg => undef,
  default  => sub{ +{} },
);

has cfg => (
  is       => 'ro',
  isa      => HashRef,
  init_arg => undef,
  default  => sub { Config->proto('irc') },
);

sub Module_register
{
  my $self = shift;

  # TODO: Logging

  module_register($self, 'SERVER', 'all');
  $self->_initialize_irc;
  return MODULE_EAT_NONE;
}

sub Module_unregister
{
  my $self = shift;
}

sub _initialize_irc
{
  my $self = shift;
  my $defaults = $self->cfg->{Network_Defaults};
  Log->debug('Initializing IRC Protocol Module');

  my ($available, $autoconnecting) = (0, 0);
  foreach my $network (keys %{$self->cfg->{Network}})
  {
    my $nethash = $self->cfg->{Network}{$network};
    my @channels = ZBCore->cfg->get_as_list($nethash->{Channels});
    my @servers;

    # Create ZeroBot::IRC::Server object(s)
    my $n = 1;
    foreach my $server (ZBCore->cfg->get_as_list($nethash->{Servers}))
    {
      my ($hostname, $port) = split /:/, $server;
      my $servhash = $nethash->{"Server$n"};
      my %server_opts = (hostname => $hostname, port => $port);

      # Helper sub to prepare %server_opts. Assigns values from the most
      # specific section first, moving upwards as needed. If there's no setting
      # at all, let the constructor handle it.
      my $prep_opts = sub {
        my ($attr, $key) = @_;
        my $val = $servhash->{$key} // $nethash->{$key} // $defaults->{$key};
        $server_opts{$attr} = $val if defined $val;
      };
      $prep_opts->(password => 'Password');
      $prep_opts->(ssl      => 'UseSSL');
      $prep_opts->(ipv6     => 'UseIPv6');

      # Set default port if unspecified
      $server_opts{port} //= $server_opts{ssl} ? 6697 : 6667;

      push @servers, ZeroBot::IRC::Server->new(%server_opts);
      ++$n;
    }
    unless (@servers)
    {
      Log->warning("Network $network does not have any servers defined! Ignoring.");
      next;
    }

    # Create ZeroBot::IRC::Network object
    my %network_opts = (
      name     => $network,
      servers  => [ @servers ],
      channels => [ map { [split / /, $_, 2] } @channels ],
    );

    # Helper sub to prepare %network_opts. Similar to the one above for servers.
    my $prep_opts = sub {
      my ($attr, $key) = @_;
      my $val = $nethash->{$key} // $defaults->{$key};
      $network_opts{$attr} = $val if defined $val;
    };
    $prep_opts->(nick      => 'Nick');
    $prep_opts->(alt_nicks => 'AltNicks');
    $prep_opts->(user      => 'User');
    $prep_opts->(gecos     => 'Gecos');
    $prep_opts->(umode     => 'UMode');

    $self->networks->{$network} = ZeroBot::IRC::Network->new(%network_opts);

    # Connect any Networks set to AutoConnect
    if ($nethash->{AutoConnect} // $self->cfg->{Network_Defaults}{AutoConnect})
    {
      # Actual connection is dispatched, so that POE can handle it like any
      # other event, and so that initialization is separate from connection,
      # which enables modules to reconnect a given network.
      module_send_event(irc_connect_network => $network);
      ++$autoconnecting;
    }
    ++$available;
  }
  if ($available)
  {
    Log->info(pluralize("Initialized %d Network(s), $autoconnecting auto-connecting", $available));
  }
  else
  {
    # TODO: Down the line when ZeroBot has a CLI, allow the user to manually
    # add a network here. For now, just do nothing and let Syndicator kill us.
    Log->warning("No IRC networks defined");
  }
}

sub _create_network_session
{
  my ($self, $network) = @_;

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
        irc_snotice

        irc_join
        irc_kick
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
      irc_public      => sub { $self->irc_spoke(MSGTYPE_MESSAGE, @_) },
      irc_msg         => sub { $self->irc_spoke(MSGTYPE_MESSAGE, @_) },
      irc_notice      => sub { $self->irc_spoke(MSGTYPE_NOTICE,  @_) },
      irc_ctcp_action => sub { $self->irc_spoke(MSGTYPE_ACTION,  @_) },
    },
  );
}

sub Bot_irc_connect_network
{
  my ($self, $core) = splice @_, 0, 2;
  my $network = ${ $_[0] };

  my $network_obj = $self->networks->{$network};
  unless (defined $network_obj)
  {
    Log->error("Attempted to connect unknown Network $network");
    return MODULE_EAT_ALL;
  }

  # TODO: Check to see if the given network is already connected. If so,
  # irc->quit with a 'Reconnecting' message and irc->connect again

  # TODO: Implement rotating to other defined servers (if specified) if the
  # first choice fails

  my $hostname = $network_obj->servers->[0]->hostname;
  my $port = $network_obj->servers->[0]->port;
  Log->info("Spawning IRC connection for Network $network, Server $hostname on port $port");

  my %spawn_opts = (
    alias      => "IRC_$network",
    Server     => $hostname,
    Port       => $port,
    Password   => $network_obj->servers->[0]->password,
    Nick       => $network_obj->nick,
    Username   => $network_obj->user,
    Ircname    => $network_obj->gecos,
    # Bitmode => ...,
    # UseSSL, SSLCert, SSLKey, SSLCtx ...
    useipv6    => $network_obj->servers->[0]->ipv6 // 0,
    Flood      => 1, # PoCo::IRC's anti-flood is overly cautious
    # PoCo::IRC will unavoidably truncate all messages greater than msg_length
    # minus nick length. Since we implement message splitting logic, set this to
    # a huge value to work around this.
    msg_length => 65536,
  );
  $spawn_opts{LocalAddr} = Config->core->{BindAddr}
    if defined Config->core->{BindAddr};

  my $irc = POE::Component::IRC::State->spawn(%spawn_opts)
    or Log->error("Failed to spawn IRC component for Network $network")
    and return MODULE_EAT_ALL;
  $network_obj->set_irc($irc);

  # Create POE::Session for IRC Component
  $self->_create_network_session($network_obj)
    or Log->error("Failed to create session for IRC component for Network $network")
    and return MODULE_EAT_ALL;

  return MODULE_EAT_ALL;
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
  $heap->{connector} = POE::Component::IRC::Plugin::Connector->new();
  $irc->plugin_add(
    Connector => $heap->{connector}
  );

  # Register for all messages/events, falling back to irc_default() if there is
  # no explicitly assigned callback
  $irc->yield(register => 'all');

  $irc->yield(connect => {});
}

sub _stop
{
  # TODO: not sure what we'll do here yet, but probably try to gracefully close
  # any running IRC sessions (if they still exist at this point), and any other
  # related cleanup
  ...
}

# TODO: Tags, special handling of certian messages (e.g. ISON, JOIN, etc.)
sub split_messsage
{
  my ($network, $msgtype, $dest, $msg) = @_;
  my $type;
  if ($msgtype < 1 or $msgtype > MSGTYPE_MAX)
  {
    carp "split_messsage: Invalid message type: $msgtype";
    return undef;
  }
  else
  {
    $type = $msgtype == MSGTYPE_NOTICE ? 'NOTICE' : 'PRIVMSG';
  }

  # TBD: Use server's NICKLEN instead of current nick length (like WeeChat)?
  # TODO: Support servers that allow lines >512 bytes
  my ($nick, $user, $host) = map($network->$_, qw/nick user host/);
  my $remaining = 510 - length(":$nick!$user\@$host $type $dest :");
  if ($msgtype == MSGTYPE_ACTION)
  {
    $remaining -= 9; # \01ACTION <msg>\01
  }

  # For normal messages, we make sure to split at a word boundary rather than
  # the last possible character, as it could be in the middle of a word,
  # creating an unnatural wrap that's harder to read.
  my @split_msg;
  if (length $msg > $remaining)
  {
    while (length $msg > $remaining)
    {
      # Find the last '-' or ' ' to split at, whichever is closest
      my $chunk = reverse substr($msg, 0, $remaining, '');
      my ($idx_s, $idx_h) = (index($chunk, ' '), index($chunk, '-'));
      my $wrap = ($idx_h > -1 and $idx_h < $idx_s) ? $idx_h : $idx_s;

      # Break at the wrap point and flip the chunk back the right way around
      my $leftover = $chunk;
      $chunk = scalar reverse substr($leftover, $wrap, length($leftover), '');
      chop $chunk if substr($chunk, -1) eq ' ';
      push @split_msg, $chunk;
      $msg = reverse($leftover) . $msg;
    }
  }
  push @split_msg, $msg;
  return @split_msg;
}

sub Bot_irc_msg_send
{
  my ($self, $core) = splice @_, 0, 2;
  my $network = ${$_[0]};
  my $dest    = ${$_[1]};
  my $msg     = join('', map($$_, @_[2..($#_-1)]));

  foreach my $chunk (split_messsage($network, MSGTYPE_MESSAGE, $dest, $msg))
  {
    $network->irc->yield(privmsg => $dest, encode_utf8($chunk));
  }
  return MODULE_EAT_NONE;
}

sub Bot_irc_action_send
{
  my ($self, $core) = splice @_, 0, 2;
  my $network = ${$_[0]};
  my $dest    = ${$_[1]};
  my $action  = join('', map($$_, @_[2..($#_-1)]));

  foreach my $chunk (split_messsage($network, MSGTYPE_ACTION, $dest, $action))
  {
    $network->irc->yield(ctcp => $dest, encode_utf8("ACTION $chunk"));
  }
  return MODULE_EAT_NONE;
}

### IRC Events #################################################

sub irc_connected
{
  my ($self, $heap, $server) = @_[OBJECT, HEAP, ARG0];
  my $network = $heap->{network};
  my $netname = $network->name;

  Log->info("[$netname] Established connection to $server, now registering...");
  $network->_set_connected_server($network->get_server($server));
}

sub irc_disconnected
{
  my ($self, $heap, $server) = @_[OBJECT, HEAP, ARG0];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $netname = $network->name;

  Log->info("[$netname] Disconnected from $server");

  $network->_set_connected(0);
  module_send_event(disconnected => $network, $server);
}

sub irc_snotice
{
  my ($self, $heap, $msg, $target, $sender) = @_[OBJECT, HEAP, ARG0 .. ARG2];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $netname = $network->name;

  # Handle server name mismatches. Typically caused by misconfigured servers.
  # TODO: Handle rare edge case of server name change after server rehash
  if ($msg =~ /Looking up your hostname/)
  {
    my $cs = $network->connected_server;
    if ($sender ne $cs->servername)
    {
      Log->verbose("[$netname] Server at ", $cs->hostname, " calls itself $sender");
      $cs->_set_servername($sender);
    }
  }

  Log->info("[$netname] $sender: $msg");
}

sub irc_welcome
{
  # 001 RPL_WELCOME
  my ($self, $heap) = @_[OBJECT, HEAP];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $netname = $network->name;

  my $server = $irc->server_name;
  Log->info("Network $netname: Successfully connected to $server");
  $network->_set_connected(1);
  $network->_set_connected_at(time);

  # Request our Username and Host from the server, as it may have mangled our
  # Username (Freenode prefixing '~' on non-ident clients), or a cloak may have
  # been applied over our Host (umode +x or otherwise).
  $irc->yield(userhost => $network->nick);

  # TODO: send 'connected' event
  # module_send_event(connected => ...);

  # Join configured channels
  my @channels = @{$network->channels};
  my @list = map $_->[0], @channels;
  local $" = ', ';
  Log->info(pluralize("[$netname] Joining %d channel(s): @list", @channels));
  foreach my $channel (@channels)
  {
    my ($name, $key) = @$channel;
    $irc->yield(join => $name, $key ? $key : ());
  }

  # Reset Alternate Nick index
  $network->get_next_alt(1);
}

sub irc_join
{
  my ($self, $heap) = @_[OBJECT, HEAP];
  my $join = ZeroBot::IRC::Event::Join->new(
    network => $heap->{network},
    src     => ZeroBot::IRC::User->new($_[ARG0]),
    dest    => $_[ARG1],
  );
  module_send_event(irc_joined => $join);
}

sub irc_kick
{
  my ($self, $heap) = @_[OBJECT, HEAP];
  my $kick = ZeroBot::IRC::Event::Kick->new(
    network => $heap->{network},
    src     => ZeroBot::IRC::User->new($_[ARG0]),
    dest    => $_[ARG1],
    reason  => $_[ARG3],
    kicked  => $_[ARG4],
  );
  module_send_event(irc_kicked => $kick)
}

sub irc_nick
{
  my ($self, $heap) = @_[OBJECT, HEAP];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $change = ZeroBot::IRC::Event::Nick->new(
    network => $network,
    src     => ZeroBot::IRC::User->new($_[ARG0]),
    dests   => $_[ARG2],
    newnick => $_[ARG1],
  );

  # The server can potentially change the bot's nick
  $network->_set_nick($change->newnick)
    if $change->src->nick eq $irc->nick_name;

  module_send_event(nick_change => $change);
}

sub irc_spoke
{
  my ($self, $msgtype) = splice @_, 0, 2;
  my ($heap, $src, $dests, $body) = @_[HEAP, ARG0 .. ARG2];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $cmdchar = ZBCore->cmdchar;

  # NOTE: It's not clear in what circumstances PoCo::IRC will supply more than
  # one destination for these events. Receiving PRIVMSGs with multiple
  # recipients merely fires the irc_(msg|public) event twice. As far as I'm
  # aware, $dests will virtually always have only one element.
  foreach my $dest (@$dests)
  {
    my %event = (
      network => $network,
      src     => ZeroBot::IRC::User->new($src),
      dest    => $dest
    );

    # TBD: Should we decode here, or let modules handle it when they need it?
    $body = decode_irc($body);

    # Determine whether this is a plain message, or a command
    if ($msgtype == MSGTYPE_MESSAGE and substr($body, 0, 1) eq $cmdchar)
    {
      my $cmd = ZeroBot::IRC::Event::Command->new(%event, line => $body);
      module_send_event(commanded => $cmd);
    }
    else
    {
      my $msg = ZeroBot::IRC::Event::Message->new(
        %event,
        type    => $msgtype,
        message => $body,
      );

      use feature 'switch';
      no warnings 'experimental::smartmatch';
      for ($msgtype)
      {
        module_send_event(irc_msg    => $msg) when MSGTYPE_MESSAGE;
        module_send_event(irc_notice => $msg) when MSGTYPE_NOTICE;
        module_send_event(irc_action => $msg) when MSGTYPE_ACTION;
      }
    }
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

  Log->error("[$netname] Network error: $errmsg");
  module_send_event(server_error => $errmsg);
}

sub irc_erroneous_nickname
{
  # 432 ERR_ERRONEUSNICKNAME
  my ($self, $heap) = @_[OBJECT, HEAP];
  my ($network, $irc) = @{$heap}{'network', 'irc'};
  my $rpl = ZeroBot::IRC::ServerReply->new($network, 432, @_[ARG0..ARG2]);
  my $badnick = $rpl->msg->[0];
  my $netname = $network->name;

  Log->error("[$netname] Erroneous Nickname: $badnick");

  # Let any intersted modules handle this event
  # NOTE: Not sure yet how we'll handle this event return here
  my $eat = module_send_event(nick_erroneous => $badnick, $rpl);
  return if $eat == MODULE_EAT_ALL;

  my $nicklen = $irc->isupport('NICKLEN');
  if (defined $nicklen and length $badnick > $nicklen)
  {
    Log->warning("[$netname] Truncating nick to fit NICKLEN");
    $irc->yield(nick => substr($badnick, 0, $nicklen));
  }
  else
  {
    # If we're in the registration phase with a bad nick, disconnect and let the
    # user correct it. Otherwise this nick change attempt was likely from some
    # bot event and we can just ignore it and move on.
    if (!$network->connected)
    {
      Log->error("[$netname] Cannot register connection with erroneous nickname; disconnecting.");
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
  my $rpl = ZeroBot::IRC::ServerReply->new($network, 433, @_[ARG0..ARG2]);
  my $nick = $rpl->msg->[0];
  my $netname = $network->name;

  Log->error("[$netname] Nick '$nick' already in use.");

  # If we're in the registration phase, this event is either due to a ghosted
  # connection with this nick, or the nick is has been stolen (or perhaps the
  # other way around ;)) For now, do what we can to register and let any
  # interested modules take over.
  if (!$network->connected)
  {
    my $newnick = $network->get_next_alt();
    unless (defined $newnick)
    {
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
    }
    $network->_set_nick($newnick);
    $irc->yield(nick => $newnick);
  }
  module_send_event(nick_in_use => $nick, $rpl);
}

sub irc_default
{
  my ($heap, $event, $args) = @_[HEAP, ARG0 .. $#_];
  my $network = $heap->{network};
  my $netname = $network->name;

  # Catch any numeric replies without a callback
  if ($event =~ /irc_(\d+)/)
  {
    my $rpl = ZeroBot::IRC::ServerReply->new($network, $1, @$args);
    module_send_event(unhandled_numeric => $rpl);
    Log->verbose("[$netname] Numeric $1: ", join(' ', @{$rpl->msg}));
    return;
  }

  # Log any other unhandled event to debug log
  my @output = ("Event $event: ");
  for my $arg (@$args)
  {
    if (ref $arg eq 'ARRAY')
    {
      push(@output, '[' . join(', ', @$arg) . ']');
    }
    else
    {
      next unless defined $arg;
      push(@output, "'$arg'");
    }
  }
  Log->debug("[$netname] ", join(' ', @output));
}

1;

