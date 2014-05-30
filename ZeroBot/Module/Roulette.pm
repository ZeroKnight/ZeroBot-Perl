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

    if ($$shot++ != $$bullet) {
        $main::irc->yield(privmsg => $channel => "CLICK! Who's next?");
        return;
    } else {
        if ($main::irc->is_channel_operator($channel, $main::irc->nick_name)) {
            $main::irc->yield(kick => $channel => $sender => "BANG! You died.");
        } else {
            $main::irc->yield(privmsg => $channel => "BANG! $sender died.");
        }
        roulette_reload($channel);
    }
    return;
}

sub roulette_reload {
    my $channel = shift;

    # XXX: POE is extremely fucking irritating about this shit.
    my $session = $poe_kernel->get_active_session();
    my $heap = $session->get_heap();

    $main::irc->yield(ctcp => $channel => "ACTION loads a single round and spins the chamber");
    $heap->{game}{roulette}{bullet} = int(rand(6));
    $heap->{game}{roulette}{shot} = 0;
}

1;

