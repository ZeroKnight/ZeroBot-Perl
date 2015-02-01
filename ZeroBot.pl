#!/usr/bin/env perl

use v5.14;
use strict;
use warnings;

use POE qw(Component::IRC::State);
use DBI;
use Math::Random::MT qw(srand rand);
use YAML qw(LoadFile);

use ZeroBot::Module::JoinGreet;
use ZeroBot::Module::Mention;
use ZeroBot::Module::Question;
use ZeroBot::Module::BadCmd;
use ZeroBot::Module::Magic8Ball;
use ZeroBot::Module::TrollXeno;
use ZeroBot::Module::Encode;
use ZeroBot::Module::Roulette;
use ZeroBot::Module::NumGuess;
use ZeroBot::Module::Puppet;
use ZeroBot::Module::Quotes;
use ZeroBot::Module::BabelBaba;

# TODO: make randomization a bit better and remember last used phrase for all
# tables, then skip it if it comes up again back-to-back

# NOTE: Use OO interface for MT when zerobot is more refined and OO
# Seed our MT PRNG
srand(time);

my $botversion = '0.1a';
my $cmdprefix = '!';
my $should_respawn = 0;

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
our $dbh = DBI->connect($dsn, '', '', {
    PrintError       => 1,
    RaiseError       => 0,
    AutoCommit       => 1,
    FetchHashKeyName => 'NAME_lc',
});

# create a new poco-irc object
our $irc = POE::Component::IRC::State->spawn(
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
            _stop
            irc_001
            irc_433
            irc_public
            irc_ctcp_action
            irc_msg
            irc_join
        ) ],
    ],
    heap => {
        irc => $irc,
        game => {
            roulette => {
                bullet => int(rand(6)),
                shot => 0,
            },
            numguess => {
                magicnum => int(rand(100)) + 1,
                guessnum => 0,
            }
        },
        quote => {
            lastcmd => undef,
            lastquote => [ undef, undef ],
        },
    },
);

$poe_kernel->run();

sub _start {
    my $heap = $_[HEAP];

    # Get the session ID of the irc component from the object created by
    # POE::Session->create()
    my $irc_session = $heap->{irc}->session_id();

    # Register for all irc events. Non-explicitly handled events will fall back
    # to _default()
    $irc->yield(register => 'all');

    # Connect to the server
    $irc->yield(connect => { });
    return;
}

sub irc_001 {
    # RPL_WELCOME
    my $sender = $_[SENDER];

    # Get the component's object by accessing the SENDER's heap
    # In any irc_* events, SENDER will be the PoCo-IRC session.
    my $irc = $sender->get_heap();
    say "Connected to ", $irc->server_name();

    # Join our channels now that we're connected
    $irc->yield(join => $_) for @{$networks{wazuhome}{channels}};
    return;
}

sub irc_433 {
    # ERR_NICKNAMEINUSE
    my $nick = $irc->nick_name;

    say "Nick: '$nick' already in use.";
    $irc->yield(nick => $nick . '_');
}

sub irc_public {
    my ($sender, $heap, $who, $where, $what) = @_[SENDER, HEAP, ARG0 .. ARG2];
    my $irc = $sender->get_heap();
    my $me = $irc->nick_name;
    my $nick = (split /!/, $who)[0];
    my $channel = $where->[0];
    my $is_chanop = $irc->is_channel_operator($channel, $me);

    foreach ($what) {
        when ($nick eq 'xxen0nxx') {
            trollxeno($channel);
        } when (/^$cmdprefix/) {
            my %cmd = parse_command($what);
            my @cmdarg = @{ $cmd{arg} }; # shortcut
            foreach ($cmd{name}) {
                when ('encode') { # TODO: add more encodings
                    encode($channel, $nick, $cmdarg[0], "@cmdarg[1 .. $#cmdarg]");
                } when ('roulette') {
                    roulette($channel, $nick);
                } when ('guess') {
                    numguess($channel, $nick, $cmdarg[0]);
                } when ('8ball') {
                    if ($what =~ /.+\?(\s+)?$/) {
                        magic_8ball_answer($channel, $nick);
                    } else {
                        magic_8ball_invalid($channel, $nick);
                    }
                # TODO: randomize phrases for restart and die
                } when ('restart') {
                    if ($nick eq 'ZeroKnight') {
                        $should_respawn = 1;
                        $irc->call(privmsg => $channel => "Okay, brb!");
                        $irc->yield(shutdown => "Restarted by $nick");
                    }
                } when ('die') {
                    if ($nick eq 'ZeroKnight') {
                        $irc->call(privmsg => $channel => "Okay :(");
                        $irc->yield(shutdown => "Killed by $nick");
                    }
                } when ('say') {
                    if ($cmdarg[0] eq '!roulette') {
                        # Nice try, wise guy
                        puppet_roulette($channel, $nick);
                    } else {
                        # Normal puppeting
                        puppet_say($channel, $nick, "@cmdarg");
                    }
                } when ('do') {
                    puppet_do($channel, $nick, "@cmdarg");
                } when ('raw') {
                    puppet_raw($nick, "@cmdarg");
                } when ('quote') {
                    compress_arg(0, \@cmdarg) if $cmdarg[0] and $cmdarg[0] =~ /^"/;
                    if (exists $cmd{opt}{add}) {
                        if (@cmdarg < 2) {
                            badcmd($channel);
                            return;
                        }
                        quote_add($channel, $nick, $cmdarg[0],
                                  "@cmdarg[1 .. $#cmdarg]",
                                  $nick, $cmd{opt}{style}
                        );
                    } elsif (exists $cmd{opt}{del}) {
                        if (exists $cmd{opt}{last}) {
                            my %quote = quote_getlast();
                            if ($quote{lastcmd} ne 'del') {
                                quote_del($channel, $nick, @{ $quote{lastquote} })
                            } else {
                                badcmd($channel);
                            }
                        } else {
                            if (@cmdarg < 2) {
                                badcmd($channel);
                                return;
                            }
                            quote_del($channel, $nick, $cmdarg[0],
                                      "@cmdarg[1 .. $#cmdarg]"
                            );
                        }
                    } elsif (exists $cmd{opt}{help}) {
                        quote_help($nick);
                    } elsif (exists $cmd{opt}{undo}) {
                        quote_undo($channel, $nick);
                    } elsif (exists $cmd{opt}{count}) {
                        quote_count($channel, $nick);
                    } else {
                        quote_recite($channel, $nick, $cmdarg[0], "@cmdarg[1 .. $#cmdarg]")
                    }
                } when ('translate') {
                    if (exists $cmd{opt}{add} or exists $cmd{opt}{del}) {
                        if (@cmdarg < 1) {
                            badcmd($channel);
                            return;
                        }
                        if (exists $cmd{opt}{add}) {
                            babelbaba_add($channel, $nick, "@cmdarg");
                        } elsif (exists $cmd{opt}{del}) {
                            babelbaba_del($channel, $nick, "@cmdarg");
                        } else {
                            babelbaba_translate($channel, $nick);
                        }
                    }
                } default {
                    badcmd($channel);
                }
            }
        } when (is_question($what)) {
            # question: Agree, disagree or be unsure with a question
            if ($what =~ /would you kindly/i) {
                answer_question($channel, $nick, 1);
            } else {
                answer_question($channel, $nick);
            }
        } when (is_nonsense($what) and $nick eq 'Wazubaba') {
            babelbaba_translate($channel, $nick, 1);
        } default {
            #mention: Respond to name being used
            respond_to_mention($channel) if /$me/i;
        }
    }
    return;
}

sub irc_msg {
    my ($sender, $who, $where, $what) = @_[SENDER, ARG0 .. ARG2];

    my $irc = $sender->get_heap();
    my $me = $irc->nick_name;
    my $nick = (split /!/, $who)[0];

    foreach ($what) {
        when (/^$cmdprefix/) {
            my %cmd = parse_command($what);
            my @cmdarg = @{ $cmd{arg} }; # shortcut
            foreach ($cmd{name}) {
                when ('say') {
                    if ($cmdarg[0] eq '!roulette') {
                        # Nice try, wise guy
                        puppet_roulette($cmdarg[0], $nick);
                    } else {
                        # Normal puppeting
                        puppet_say($cmdarg[0], $nick, "@cmdarg[1 .. $#cmdarg]");
                    }
                } when ('do') {
                    puppet_do($cmdarg[0], $nick, "@cmdarg[1 .. $#cmdarg]");
                } when ('raw') {
                    puppet_raw($nick, "@cmdarg");
                } default {
                    badcmd($nick);
                }
            }
        } when (is_question($what)) {
            answer_question($nick);
        } default {
            # Freak out for being msg'd for no reason
            respond_to_mention($nick) if /$me/i;
        }
    }
}

sub irc_ctcp_action {
    my ($sender, $heap, $who, $where, $what) = @_[SENDER, HEAP, ARG0 .. ARG2];
    my $irc = $sender->get_heap();
    my $me = $irc->nick_name;
    my $nick = (split /!/, $who)[0];
    my $channel = $where->[0];

    foreach ($what) {
        when (is_question($what)) {
            #mention: Respond to name being used
            answer_question($channel, $nick);
        } when (is_nonsense($what) and $nick eq 'Wazubaba') {
            babelbaba_translate($channel, $nick, 1);
        } default {
            respond_to_mention($channel) if /$me/i;
        }
    }
    return;
}

sub irc_join {
    my ($sender, $who, $where) = @_[SENDER, ARG0, ARG1];
    my $irc = $sender->get_heap();
    my $nick = (split /!/, $who)[0];

    # joingreet: Greet channel
    greet($where) if $irc->nick_name eq $nick;
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
    if ($should_respawn) {
        say 'Restarting...';
        exec "$0 $ARGV[0]";
    } else {
        exit 0;
    }
}

sub parse_command {
    my ($lastarg, $need_optval, @opt, @val);
    my $parse_opts = 1;
    my %cmdhash = (
        name => undef,
        opt => {},
        arg => []
    );

    foreach my $arg (split /\s+/, shift) {
        if ($need_optval) {
            if ($arg =~ /"$/) { # End of value; add to hash
                push @val, $arg =~ tr/"//dr;
                $cmdhash{opt}{$opt[0]} = join(' ', @val);
                $need_optval = 0;
                @opt = (); @val = ();
            } else { # Still part of value
                push @val, $arg;
            }
        } else {
            if ($parse_opts and $arg =~ /^!\w+/) {
                # Command Name
                $cmdhash{name} = $arg =~ tr/!//dr;
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
                    $cmdhash{opt}{$opt[0]} = $opt[1];
                }
            } elsif ($parse_opts and $arg =~ /^-\w+/) {
                # Option with no value
                $arg =~ tr/-//d;
                $cmdhash{opt}{$arg} = undef;
            } else {
                # We've hit arguments, stop parsing options (and name)
                $parse_opts = 0 if $parse_opts;
                push $cmdhash{arg}, $arg;
            }
        }
    }
    return %cmdhash;
}

sub compress_arg {
    # Compress quoted args into one. Takes an array reference
    # TODO: add this and parse_command to ZeroBot::Util; croak if $args is not a reference
    my ($start, $args) = @_;

    unless (@$args == 1) {
        my $index = $start;
        $index++ until $args->[$index] =~ /"$/;
        splice @$args, $start, $index+1, "@$args[$start .. $index]";
    }
    $args->[$start] =~ tr/"//d;
}

