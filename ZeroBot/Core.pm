package ZeroBot::Core;

# Probably not right, but there doesn't seem to be a consensus on the proper way
# to do module versions...
our $VERSION = '0.1';

use 5.014; # hashref: keys values; push on scalars
use Moose;
use Carp;
use Try::Tiny;
use Math::Random::MT;
use Encode qw(encode);
use Storable qw(dclone);
use Text::Wrap ();
use DBI;
use YAML::XS qw(LoadFile DumpFile);
use IRC::Utils qw(decode_irc);
use POE qw(Component::IRC::State Component::IRC::Plugin::Connector);
use Module::Pluggable
    sub_name => '_available_modules',
    search_path => ['Modules'];

#use ZeroBot::Database;
#use ZeroBot::ModuleManager;

has 'Nick' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'ZeroBot',
);

has 'User' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'zerobot',
);

has 'Gecos' => (
    is      => 'rw',
    isa     => 'Str',
    default => "ZeroBot v$VERSION",
);

has 'Hostname' => (
    is       => 'rw',
    isa      => 'Str',
    init_arg => undef,
);

has 'Networks' => (
    is  => 'rw',
    isa => 'HashRef',
);

has 'CmdChar' => (
    is  => 'rw',
    #isa => subtype('Str' => where { length == 1 }),
    isa => 'Str',
    default => '!',
);

has 'Config' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'ZeroBot.yaml',
);

has 'Database' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'ZeroBot.sqlite',
);

has '_dbh' => (
    is      => 'rw',
    isa     => 'DBI::db',
    init_arg => undef,
);

has '_ircobj' => (
    is       => 'rw',
    isa      => 'POE::Component::IRC::State',
    init_arg => undef,
);

has '_cmdhash' => (
    is       => 'rw',
    isa      => 'HashRef',
    init_arg => undef,
);

has 'Modules' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
    #builder => '_autoload_modules',
);

sub BUILD {
    my ($self, $args) = @_;

    # Get settings from config
    my $config = LoadFile('config/' . $self->Config);
    while (my ($node, $value) = each $config) {
        if ($node eq 'Identity') {
            while (($node, $value) = each $config->{Identity}) {
                $self->$node($value);
            }
        } elsif ($node eq 'Networks') {
            $self->Networks(dclone $value);
        } elsif ($node eq 'Settings') {
            while (($node, $value) = each $config->{Settings}) {
                $self->$node($value);
            }
        }
    }

    # Get a handle to our database
    $self->_dbh(DBI->connect(
        "dbi:SQLite:dbname=" . $self->Database, '', '', {
            PrintWarn => 1,
            PrintError => 1,
            AutoCommit => 1,
        }
    ));
    unless (defined $self->_dbh) {
        croak "Unable to connect to database '$self->Database': $DBI::errstr";
    }

    # Autoload existing modules
    $self->_autoload_modules();
}

sub run {
    my $self = shift;

    # Create a session and assign callbacks to handle the IRC messages/events
    POE::Session->create(
        object_states => [
            $self => {
                _default        => 'irc_default',
                _start          => 'irc_start',
                _stop           => 'irc_stop',

                irc_connected   => 'irc_connected',
                irc_001         => 'irc_welcome',
                irc_433         => 'irc_nickname_in_use',
                irc_error       => 'irc_error',

                irc_join        => 'irc_join',
                irc_nick        => 'irc_nick',
            },
        ],
        # Inline because this way we don't need 4 identical subs, or a bunch of
        # helper subs feeding to irc_spoke
        inline_states => {
            irc_public      => sub { $self->irc_spoke('channel', @_) },
            irc_msg         => sub { $self->irc_spoke('msg', @_) },
            irc_notice      => sub { $self->irc_spoke('notice', @_) },
            irc_ctcp_action => sub { $self->irc_spoke('action', @_) },
        },
    );

    $poe_kernel->run();
    return;
}

sub load {
    my ($self, $module) = @_;

    # Check whether module is already loaded
    if ($self->Modules->{$module}) {
        carp "Module '$module' already loaded";
        return undef;
    }

    my $file = "Modules/$module.pm";
    try { require $file } catch { croak "Failed to load module '$module': $_"; };

    my $m = "Modules::$module"->new(Bot => $self);
    $self->Modules->{$module} = $m;
}

sub reload { ... }

sub unload { ... }

sub _autoload_modules {
    my $self = shift;

    foreach my $module (_available_modules()) {
        $module =~ s/.*:://g;
        $self->load($module);
    }
}

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

###############################
### PoCo-IRC Callbacks
###############################

sub irc_start {
    my ($self, $kernel, $session) = @_[OBJECT, KERNEL, SESSION];
    # NOTE: Can register signals here (eg. DIE)

    # TODO: Use POE::Component::IRC::Plugin::Proxy for our connection to allow
    # for seamless restarts and on-the-fly changes

    # NOTE: Set an alias?
    $self->_ircobj(POE::Component::IRC::State->spawn());

    # Connector handles automatic reconnection to an IRC server
    $self->_ircobj->plugin_add(
        Connector => POE::Component::IRC::Plugin::Connector->new()
    );

    # Register for all messages/events, falling back to _default() if there is
    # no explicitly assigned callback
    $self->_ircobj->yield(register => 'all');

    # ...and connect!
    say 'Connecting to ', 'wazu.info.tm', ' on port ', 6667; # XXX: temp
    $self->_ircobj->yield(connect => {
        Nick       => $self->Nick,
        Username   => $self->User,
        Ircname    => $self->Gecos,
        Server     => 'wazu.info.tm', # XXX: temp
        #Port       => $self->port,
        #UseSSL     => $self->ssl,
        Flood      => 1, # PoCoIRC's Anti-Flood is overcautious
        msg_length => 512,
    });

    return;
}

sub irc_connected {
    my ($self, $server) = @_[OBJECT, ARG0];

    say 'Successfully connected to ', $server;
}

sub irc_welcome {
    # 001 RPL_WELCOME
    my $self = $_[OBJECT];

    # XXX: temp
    foreach my $channel (@{$self->Networks->{wazuhome}{Channels}}) {
        say "Joining '$channel'";
        $self->_ircobj->yield(join => $channel);
    }

    foreach my $module (values $self->Modules) {
        next unless $module->can('connected');
        $module->connected();
    }
}

sub irc_nickname_in_use {
    # 443 ERR_NICKNAMEINUSE
    my $self = $_[OBJECT];

    say "Nick: '" . $self->Nick . "' already in use.";
    $self->Nick($self->Nick . '_');
    $self->_ircobj->yield(nick => $self->Nick);
}

sub irc_spoke {
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
            my @modules = (keys $self->Modules);
            unless ($arg[0]) {
                $self->privmsg($msg->{where} =>
                    ($msgtype eq 'msg' ? '' : "$nick: ") .
                    "Specify a module to see help for. Loaded modules: @modules"
                );
                return;
            }
            if (grep {$_ eq $arg[0]} @modules) {
                $self->notice($nick => $_) for $self->Modules->{$arg[0]}->help();
                return;
            } else {
                $self->privmsg($msg->{where} =>
                    ($msgtype eq 'msg' ? '' : "$nick: ") .
                    "No module named '$arg[0]' is loaded. Loaded modules: @modules"
                );
                return;
            }
        } else { # Command issued
            foreach my $module (values $self->Modules) {
                next unless $module->can('commanded');
                $module->commanded($msg, $self->_cmdhash);
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

sub irc_join {
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

sub irc_nick {
    my ($self, $who, $newnick) = @_[OBJECT, ARG0, ARG1];

    $self->Nick($newnick) if (split /!/, $who)[0] eq $self->Nick;
}

sub irc_default {
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
    say "@output";
    return;
}

sub irc_stop {
    return;
}

sub irc_error {
    return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
