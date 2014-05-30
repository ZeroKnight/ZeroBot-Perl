#!/usr/bin/env perl

package ZeroBot::Module::BadCmd;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(badcmd badcmd_add badcmd_del);

my $module_name = 'BadCmd';

sub badcmd {
    my $target = shift;

    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM badcmd
        ORDER BY RANDOM() LIMIT 1
    });
    if ($ary[1]) {
        $main::irc->yield(ctcp => $target => "ACTION $ary[0]");
    } else {
        $main::irc->yield(privmsg => $target => $ary[0]);
    }
}

sub badcmd_add {
    my ($target, $sender, $phrase, $action) = @_;

    $main::dbh->do(q{
        INSERT INTO badcmd(phrase, action)
        VALUES (?, ?)
    }, undef, ($phrase, int($action))) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, adding " . $action ? 'action' : 'phrase' .
        " \"$phrase\" to $module_name"
    );
}

sub badcmd_del {
    my ($target, $sender, $phrase) = @_;

    $main::dbh->do(q{
        DELETE FROM badcmd
        WHERE phrase=?
    }, undef, $phrase) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, removing \"$phrase\" from $module_name"
    );
}

1;
