#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use DBI;
use POE qw(Component::IRC::State);

# TODO: move this somewhere that makes sense
srand(time * 1000);

my $botversion = '0.1a';
my $cmdprefix = '!';

# TODO: move this to config-related shit
my %networks = (
    wazuhome => {
        servers => ['wazu.info.tm'],
        channels => ['#zerobot'],
        nickname => 'ZeroBot',
        username => 'ZeroBot',
        realname => "ZeroBot v$botversion",
    },
);
# XXX: temporary
$networks{wazuhome}{channels} = ["$ARGV[0]"] if $ARGV[0];

# TODO: move this to database-related shit
my $dbfile = 'zerobot.db';
my $dsn = "dbi:SQLite:dbname=$dbfile";
my $dbh = DBI->connect($dsn, '', '', {
    PrintError       => 1,
    RaiseError       => 0,
    AutoCommit       => 0,
    FetchHashKeyName => 'NAME_lc',
});

# create a new poco-irc object
my $poco_irc = POE::Component::IRC::State->spawn(
    nick => $networks{wazuhome}{nickname},
    username => $networks{wazuhome}{username},
    ircname => $networks{wazuhome}{realname},
    server => $networks{wazuhome}{servers}[0],
    flood => 1,
) or die "spawn: failed to create IRC object; $!";

POE::Session->create(
    package_states => [
        main => [ qw(
            _default
            _start
            irc_001
            irc_public
            irc_join
        ) ],
    ],
    heap => {
        poco_irc => $poco_irc,
        game => {
            roulette => {
                bullet => int(rand(6)),
                shot => 0,
            },
        },
    },
);

$poe_kernel->run();

sub _start {
    my $heap = $_[HEAP];

    # Get the session ID of the irc component from the object created by
    # POE::Session->create()
    my $irc_session = $heap->{poco_irc}->session_id();

    # Register for all irc events (non-explicitly handled events will fall back
    # to _default()
    $poco_irc->yield(register => 'all');

    # Connect to the server
    $poco_irc->yield(connect => { });
    return;
}

sub irc_001 {
    # RPL_WELCOME
    my $sender = $_[SENDER];

    # Get the component's object by accessing the SENDER's heap
    # In any irc_* events, SENDER will be the PoCo-IRC session.
    my $poco_irc = $sender->get_heap();
    say "Connected to ", $poco_irc->server_name();

    # Join our channels now that we're connected
    $poco_irc->yield(join => $_) for @{$networks{wazuhome}{channels}};
    return;
}

sub irc_public {
    my ($sender, $heap, $who, $where, $what) = @_[SENDER, HEAP, ARG0 .. ARG2];
    my $poco_irc = $sender->get_heap();
    my $me = $poco_irc->nick_name;
    my $nick = (split /!/, $who)[0];
    my $channel = $where->[0];

    if ($what =~ /right,? $me\??/i) {
        # chat_agree: Agree or disagree when someone asks
        chat_agree($channel) if module_enabled('chat_agree');
    } elsif ($what =~ /$me/) {
        # chat_mention: Respond to name being used
        chat_mention($channel) if module_enabled('chat_mention');
    } elsif ($what =~ /^$cmdprefix/) {
        my $cmd = (split /$cmdprefix|\s/, $what)[1];
        if ($cmd eq 'encode') {
            cmd_encode(
                (split /\s/, $what, 3)[2],
                (split /\s/, $what)[1],
                $channel
            );
        } elsif ($cmd eq 'roulette') {
            cmd_roulette($heap, $channel, $nick);
        } else {
            chat_badcmd($channel) if module_enabled('chat_badcmd');
        }
    }
    return;
}

sub irc_join {
    my ($sender, $who, $where) = @_[SENDER, ARG0, ARG1];
    my $poco_irc = $sender->get_heap();
    my $nick = (split /!/, $who)[0];

    if ($poco_irc->nick_name eq $nick) {
        # chat-joingreet: Greet channel
        chat_joingreet($where) if module_enabled('chat_joingreet');
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
    print join ' ', @output, "\n";
    return;
}

# TODO: move this to module-related shit
sub module_enabled {
    return 1;
}

# TODO: Move repetative sql setup to function?
sub chat_joingreet {
    my $channel = shift;
    my $sql = 'SELECT * FROM chat_joingreet ORDER BY RANDOM() LIMIT 1';
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my $href = $sth->fetchrow_hashref;
    unless ($href->{action}) {
        $poco_irc->yield(privmsg => $channel => $href->{phrase});
    } else {
        $poco_irc->yield(ctcp => $channel => "ACTION $href->{phrase}");
    }
}

sub chat_mention {
    my $channel = shift;
    my $sql = 'SELECT * FROM chat_mention ORDER BY RANDOM() LIMIT 1';
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my $href = $sth->fetchrow_hashref;
    unless ($href->{action}) {
        $poco_irc->yield(privmsg => $channel => $href->{phrase});
    } else {
        $poco_irc->yield(ctcp => $channel => "ACTION $href->{phrase}");
    }
}

sub chat_agree {
    my $channel = shift;
    my $sql = 'SELECT * FROM chat_agree WHERE agree=' . int(rand(2)) . ' ORDER BY RANDOM() LIMIT 1';
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my $href = $sth->fetchrow_hashref;
    unless ($href->{action}) {
        $poco_irc->yield(privmsg => $channel => $href->{phrase});
    } else {
        $poco_irc->yield(ctcp => $channel => "ACTION $href->{phrase}");
    }
}

sub chat_badcmd {
    my $channel = shift;
    my $sql = 'SELECT * FROM chat_badcmd ORDER BY RANDOM() LIMIT 1';
    my $sth = $dbh->prepare($sql);
    $sth->execute;
    my $href = $sth->fetchrow_hashref;
    unless ($href->{action}) {
        $poco_irc->yield(privmsg => $channel => $href->{phrase});
    } else {
        $poco_irc->yield(ctcp => $channel => "ACTION $href->{phrase}");
    }
}

sub cmd_encode {
    my ($input, $algorithm, $channel) = @_;
    if ($algorithm eq 'rot13') {
        $input =~ tr[a-zA-Z][n-za-mN-ZA-M];
        $poco_irc->yield(privmsg => $channel => $input);
    } else {
        return '';
    }
}

sub cmd_roulette {
    my ($heap, $channel, $nick) = @_;
    my $bullet = \$heap->{game}{roulette}{bullet};
    my $shot = \$heap->{game}{roulette}{shot};

    if ($$shot++ != $$bullet) {
        $poco_irc->yield(privmsg => $channel => "CLICK! Who's next?");
        return;
    } else {
        if ($poco_irc->is_channel_operator(
                $channel,
                $poco_irc->nick_name,
        )) {
            $poco_irc->yield(kick => $channel => $nick => "BANG! You died.");
        } else {
            $poco_irc->yield(privmsg => $channel => "BANG! $nick died.");
        }
        $$bullet = int(rand(6));
        $poco_irc->yield(ctcp => $channel => "ACTION loads a single round and spins the chamber");
        $$shot = 0;
    }
    return;
}
