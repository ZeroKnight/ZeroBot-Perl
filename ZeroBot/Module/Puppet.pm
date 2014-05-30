#!/usr/bin/env perl

package ZeroBot::Module::Puppet;

use v5.14;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(puppet_say puppet_do puppet_raw puppet_roulette);

my $module_name = 'Puppet';

use ZeroBot::Module::Roulette;

sub puppet_say {
    my ($target, $sender, $msg) = @_;

    say "[*] $sender => $target: \"$msg\"";
    $main::irc->yield(privmsg => $target => $msg);
}

sub puppet_do {
    my ($target, $sender, $msg) = @_;

    say "[*] $sender *=> $target: \"$msg\"";
    $main::irc->yield(ctcp => $target => "ACTION $msg");
}

sub puppet_raw {
    my ($sender, $rawline) = @_;

    say "[*] $sender => RAW: $rawline";
    $main::irc->yield(quote => $rawline);
}

sub puppet_roulette {
    my ($channel, $sender) = @_;

    $main::irc->call(ctcp => $channel =>
        "ACTION laughs and rotates the chamber, pointing the gun at $sender"
    );
    if ($main::irc->is_channel_operator($channel, $main::irc->nick_name)) {
        $main::irc->yield(kick => $channel => $sender =>
            "BANG! You aren't as clever as you think."
        );
    } else {
        $main::irc->yield(privmsg => $channel =>
            "BANG! You aren't as clever as you think."
        );
    }
    roulette_reload($channel);
}

1;
