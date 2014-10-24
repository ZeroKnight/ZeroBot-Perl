#!/usr/bin/env perl

use v5.14;
use strict;
use warnings;

use POE qw(Component::IRC::State);
use DBI;
use Math::Random::MT qw(srand rand);

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

    given ($what) {
        when ($nick eq 'xxen0nxx') {
            trollxeno($channel);
        } when (/^$cmdprefix/) {
            my @cmd = parse_command($what);
            given ($cmd[0]) {
                when ('encode') { # TODO: add more encodings
                    encode($channel, $nick, $cmd[1], "@cmd[2 .. $#cmd]");
                } when ('roulette') {
                    roulette($channel, $nick);
                } when ('guess') {
                    numguess($channel, $nick, $cmd[1]);
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
                    if ($cmd[1] !~ /roulette/) {
                        # Normal puppeting
                        puppet_say($channel, $nick, "@cmd[1 .. $#cmd]");
                    } else {
                        # Nice try, wise guy
                        puppet_roulette($channel, $nick);
                    }
                } when ('do') {
                    puppet_do($channel, $nick, "@cmd[1 .. $#cmd]");
                } when ('raw') {
                    puppet_raw($nick, "@cmd[1 .. $#cmd]");
                } when ('quote') {
                    given ($cmd[1]) {
                        when ('-add') {
                            if (@cmd < 4) {
                                badcmd($channel);
                                return;
                            }
                            my ($author, $style, $phrase);
                            if ($cmd[2] eq '-style') {
                                if (@cmd < 6) {
                                    badcmd($channel);
                                    return;
                                }
                                $style = $cmd[3];
                                $author = $cmd[4];
                                $phrase = "@cmd[5 .. $#cmd]";
                            } else {
                                $author = $cmd[2];
                                $phrase = "@cmd[3 .. $#cmd]";
                            }
                            quote_add($channel, $nick, $author, $phrase, $nick, $style);
                        } when ('-del') {
                            if (@cmd < 4) {
                                badcmd($channel);
                                return;
                            }
                            quote_del($channel, $nick, $cmd[2], "@cmd[3 .. $#cmd]");
                        } default {
                            quote_recite($channel, $nick, "@cmd[1 .. $#cmd]");
                        }
                    }
                } when ('translate') {
                    given ($cmd[1]) {
                        when ('-add') {
                            if (@cmd < 3) {
                                badcmd($channel);
                                return;
                            }
                            babelbaba_add($channel, $nick, "@cmd[2 .. $#cmd]");
                        } when ('-del') {
                            if (@cmd <3) {
                                badcmd($channel);
                                return;
                            }
                            babelbaba_del($channel, $nick, "@cmd[2 .. $#cmd]");
                        } default {
                            babelbaba_translate($channel, $nick);
                        }
                    }
                } default {
                    badcmd($channel);
                }
            }
        } when (is_question($what)) {
            # question: Agree, disagree or be unsure with a question
            answer_question($channel, $nick);
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

    given ($what) {
        when (/^$cmdprefix/) {
            my @cmd = parse_command($what);
            given ($cmd[0]) {
                when ('say') {
                    if ($cmd[2] !~ /roulette/) {
                        # Normal puppeting
                        puppet_say($cmd[1], $nick, "@cmd[2 .. $#cmd]");
                    } else {
                        # Nice try, wise guy
                        puppet_roulette($cmd[1], $nick);
                    }
                } when ('do') {
                    puppet_do($cmd[1], $nick, "@cmd[2 .. $#cmd]");
                } when ('raw') {
                    puppet_raw($nick, "@cmd[1 .. $#cmd]");
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

    #mention: Respond to name being used
    respond_to_mention($channel) if $what =~ /$me/i;
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
    my @args = (split /\s/, shift);
    $args[0] =~ tr/!//d; # trim $cmdprefix
    return @args;
}

#sub parse_command {
    #my (%cmdhash, $lastarg);
    #foreach my $arg (split /\s/, shift) {
        #if ($arg =~ /^-/) { # NOTE: this might be compressable
            #if ($lastarg =~ /^-/) {
                #$cmdhash{$arg} = undef;
            #} else {
                #$cmdhash{$lastarg} = $arg;
            #}
        #}
    #} continue {
        #$lastarg = $arg;
    #}
        #if arg starts with '-'
            #add arg to hash as key
            #if next arg also starts with '-'
                #add arg to hash as key
            #else
                #add arg as value to last key
        #else
            #add arg to hash as key
#}
