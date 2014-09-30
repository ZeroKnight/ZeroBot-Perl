#!/usr/bin/env perl

package ZeroBot::Module::Roulette;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(roulette roulette_reload);

my $module_name = 'Roulette';

use POE;

sub roulette {
    my ($channel, $sender) = @_;

    # XXX: POE is extremely fucking irritating about this shit.
    my $session = $poe_kernel->get_active_session();
    my $heap = $session->get_heap();

    my $bullet = \$heap->{game}{roulette}{bullet};
    my $shot = \$heap->{game}{roulette}{shot};
    my $target = $sender;
    my $scapegoat;

    if ($$shot++ != $$bullet) {
        roulette_reload($channel, 1) if $$shot > $$bullet; # Failsafe
        $main::irc->yield(privmsg => $channel => "CLICK! Who's next?");
        return;
    } else {
        # TODO: un-hardcode the master user
        if ($target eq 'ZeroKnight') {
            my @nicklist = grep { $_ ne 'ZeroKnight' } $main::irc->channel_list($channel);
            $scapegoat = $nicklist[int(rand(scalar @nicklist))];
            $main::irc->yield(privmsg => $channel =>
                "The bullet somehow misses and hits $scapegoat instead!");
            $target = $scapegoat;
        }
        if ($main::irc->is_channel_operator($channel, $main::irc->nick_name)) {
            $main::irc->yield(kick => $channel => $target => "BANG! You died.");
        } else {
            if (!defined $scapegoat) {
                $main::irc->yield(privmsg => $channel => "BANG! $target died.");
            }
        }
        if ($target eq $main::irc->nick_name) {
            # Resurrect
            sleep 3;
            # TODO: establish OO and support key-locked channels
            $main::irc->yield(join => $channel);
            $main::irc->yield(ctcp => $channel => "ACTION has been resurrected by forces unknown");
        }
        roulette_reload($channel);
    }
    return;
}

sub roulette_reload {
    my ($channel, $squelch) = @_;

    # XXX: POE is extremely fucking irritating about this shit.
    my $session = $poe_kernel->get_active_session();
    my $heap = $session->get_heap();

    if (!defined $squelch) {
        $main::irc->yield(ctcp => $channel =>
            "ACTION loads a single round and spins the chamber");
    }
    $heap->{game}{roulette}{bullet} = int(rand(6));
    $heap->{game}{roulette}{shot} = 0;
}

1;

