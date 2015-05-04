package ZeroBot::Core;

# Probably not right, but there doesn't seem to be a consensus on the proper way
# to do module versions...
our $VERSION = '0.1';

use 5.014; # hashref: keys values
use Moose;
use Carp;
use Math::Random::MT;
use Encode qw(encode);
use Storable qw(dclone);
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

has 'Networks' => (
    is  => 'rw',
    isa => 'HashRef',
);

has 'Cmdchar' => (
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

has 'Modules' => (
    is  => 'rw',
    isa => 'HashRef',
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
            $self => [ qw(
                _default
                _start
                _stop
                irc_001
                irc_433
                irc_public
                irc_msg
                irc_ctcp_action
                irc_join
            ) ],
        ],
        #heap => {
            #irc => $irc,
            #game => {
                #roulette => {
                    #bullet => int(rand(6)),
                    #shot => 0,
                #},
                #numguess => {
                    #magicnum => int(rand(100)) + 1,
                    #guessnum => 0,
                #}
            #},
            #quote => {
                #lastcmd => undef,
                #lastquote => [ undef, undef ],
                #lastedit => [ undef, undef ],
            #},
        #},
    );

    $poe_kernel->run();
    return;
}

sub load {
    my $self = shift;
    my $module = shift;

    $module =~ s/.*:://g;

    # Check whether module is already loaded
    if ($self->Modules->{$module}) {
        carp "Module '$module' already loaded";
        return undef;
    }

    my $file = "Modules/$module.pm";
    #try { require $file } catch { croak "Failed to load module '$module': $_"; };
    #try { require $file } catch { croak "Failed to load module '$module'"; };
    require $file;

    my $m = "Modules::$module"->new(Bot => $self);
    $self->Modules->{$module} = $m;
}

sub reload { ... }

sub unload { ... }

sub _autoload_modules {
    my $self = shift;

    foreach my $module (_available_modules()) {
        $self->load($module);
    }
}

###############################
### PoCo-IRC Callbacks
###############################

sub _start {
    my ($self, $kernel, $session) = @_[OBJECT, KERNEL, SESSION];
    # NOTE: Can register signals here (eg. DIE)

    # TODO: Use POE::Component::IRC::Plugin::Proxy for our connection to allow
    # for seamless restarts andn on-the-fly changes

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
    say 'Connecting to ', 'wazu.info.tm', 'on port ', 6667; # XXX: temp
    $self->_ircobj->yield(connect => {
        Nick     => $self->Nick,
        Username => $self->User,
        Ircname  => $self->Gecos,
        Server   => 'wazu.info.tm', # XXX: temp
        #Port     => $self->port,
        #UseSSL   => $self->ssl,
        Flood    => 1, # PoCoIRC's Anti-Flood is overcautious
    });

    return;
}

sub irc_001 {
    # RPL_WELCOME
    my $self = $_[OBJECT];

    say 'Successfully connected to ', $self->_ircobj->server_name();

    # XXX: temp
    foreach my $channel (@{$self->Networks->{wazuhome}{Channels}}) {
        say "Joining '$channel'";
        $self->_ircobj->yield(join => $channel);
    }
}

sub irc_433 {
    # ERR_NICKNAMEINUSE
    my $self = $_[OBJECT];

    say "Nick: '" . $self->Nick . "' already in use.";
    $self->Nick($self->Nick . '_');
    $self->_ircobj->yield(nick => $self->Nick);
}

sub irc_public {
    return;
}

sub irc_msg {
    return;
}

sub irc_ctcp_action {
    return;
}

sub irc_join {
    my ($self, $who, $where) = @_[OBJECT, ARG0, ARG1];
    my $irc = $self->_ircobj;
    my $nick = (split /!/, $who)[0];

    foreach my $module (values $self->Modules) {
        next unless $module->can('joined');
        $module->joined($nick, $where);
    }
    return;
}

sub _default {
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

sub _stop {
    return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
