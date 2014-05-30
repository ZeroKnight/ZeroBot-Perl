#!/usr/bin/env perl

package ZeroBot::Module::TrollXeno;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(trollxeno trollxeno_add trollxeno_del);

my $module_name = 'TrollXeno';

# TODO: make clever use of alarm() to flood protect?
sub trollxeno {
    my $channel = shift;

    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM trollxeno
        ORDER BY RANDOM() LIMIT 1
    });
    if ($ary[1]) {
        $main::irc->yield(ctcp => $channel => "ACTION $ary[0]");
    } else {
        $main::irc->yield(privmsg => $channel => $ary[0]);
    }
}

sub trollxeno_add {
    my ($target, $sender, $phrase, $action) = @_;

    $main::dbh->do(q{
        INSERT INTO trollxeno(phrase, action)
        VALUES (?, ?)
    }, undef, ($phrase, int($action))) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, adding " . $action ? 'action' : 'phrase' .
        " \"$phrase\" to $module_name"
    );
}

sub trollxeno_del {
    my ($target, $sender, $phrase) = @_;

    $main::dbh->do(q{
        DELETE FROM trollxeno
        WHERE phrase=?
    }, undef, $phrase) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, removing \"$phrase\" from $module_name"
    );
}

1;
