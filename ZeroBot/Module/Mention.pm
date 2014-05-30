#!/usr/bin/env perl

package ZeroBot::Module::Mention;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(respond_to_mention mention_add mention_del);

my $module_name = 'Mention';

sub respond_to_mention {
    my $target = shift;

    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM mention
        ORDER BY RANDOM() LIMIT 1
    });
    if ($ary[1]) {
        $main::irc->yield(ctcp => $target => "ACTION $ary[0]");
    } else {
        $main::irc->yield(privmsg => $target => $ary[0]);
    }
}

sub mention_add {
    my ($target, $sender, $phrase, $action) = @_;

    $main::dbh->do(q{
        INSERT INTO mention(phrase, action)
        VALUES (?, ?)
    }, undef, ($phrase, int($action))) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, adding " . $action ? 'action' : 'phrase' .
        " \"$phrase\" to $module_name"
    );
}

sub mention_del {
    my ($target, $sender, $phrase) = @_;

    $main::dbh->do(q{
        DELETE FROM mention
        WHERE phrase=?
    }, undef, $phrase) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, removing \"$phrase\" from $module_name"
    );
}

1;
