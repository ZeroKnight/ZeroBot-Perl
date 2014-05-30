#!/usr/bin/env perl

package ZeroBot::Module::NumGuess;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(numguess);

my $module_name = 'NumGuess';

use POE;
use ZeroBot::Module::BadCmd;

sub numguess {
    my ($channel, $sender, $guess) = @_;

    # XXX: POE is extremely fucking irritating about this shit.
    my $session = $poe_kernel->get_active_session();
    my $heap = $session->get_heap();

    my $magicnum = \$heap->{game}{numguess}{magicnum};
    my $guessnum = \$heap->{game}{numguess}{guessnum};

    if ($guess !~ /\d+/) {
        # TODO: Randomize these phrases
        $main::irc->yield(privmsg => $channel => "$sender: Try a number...");
        return;
    }

    $$guessnum++;
    if ($guess == $$magicnum) {
        $main::irc->yield(privmsg => $channel =>
            "DING! $sender wins! It took a total of $$guessnum guesses."
        );
        $main::irc->yield(privmsg => $channel =>
            "I'm thinking of another number between 1-100 ...can you guess it?"
        );
        $$magicnum = int(rand(100)) + 1;
        $$guessnum = 0;
    } elsif ($guess > $$magicnum) {
        $main::irc->yield(privmsg => $channel => "$sender: Too high!");
    } elsif ($guess < $$magicnum) {
        $main::irc->yield(privmsg => $channel => "$sender: Too low!");
    } else {
        badcmd($channel);
    }
}

1;
