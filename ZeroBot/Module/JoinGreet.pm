#!/usr/bin/env perl

package ZeroBot::Module::JoinGreet;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(greet greet_add greet_del);

my $module_name = 'JoinGreet';

sub greet {
    my $channel = shift;

    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM joingreet
        ORDER BY RANDOM() LIMIT 1
    });
    if ($ary[1]) {
        $main::irc->yield(ctcp => $channel => "ACTION $ary[0]");
    } else {
        $main::irc->yield(privmsg => $channel => $ary[0]);
    }
}

sub greet_add {
    my ($target, $sender, $phrase, $action) = @_;

    $main::dbh->do(q{
        INSERT INTO joingreet(phrase, action)
        VALUES (?, ?)
    }, undef, ($phrase, int($action))) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, adding " . $action ? 'action' : 'phrase' .
        " \"$phrase\" to $module_name"
    );
}

sub greet_del {
    my ($target, $sender, $phrase) = @_;

    $main::dbh->do(q{
        DELETE FROM joingreet
        WHERE phrase=?
    }, undef, $phrase) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, removing \"$phrase\" from $module_name"
    );
}

1;
