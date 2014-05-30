#!/usr/bin/env perl

package ZeroBot::Module::Magic8Ball;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(magic_8ball_answer magic_8ball_invalid magic_8ball_add magic_8ball_del);

my $module_name = 'Magic8Ball';

sub magic_8ball_answer {
    my ($target, $sender) = @_;

    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM magic_8ball
        WHERE refusal=0
        ORDER BY RANDOM() LIMIT 1
    });
    $main::irc->yield(privmsg => $target => "$sender: $ary[0]");
}

sub magic_8ball_invalid {
    my ($target, $sender) = @_;

    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM magic_8ball
        WHERE refusal=1
        ORDER BY RANDOM() LIMIT 1
    });
    $main::irc->yield(privmsg => $target => "$sender: $ary[0]");
}

sub magic_8ball_add {
    my ($target, $sender, $phrase, $refusal) = @_;

    $main::dbh->do(q{
        INSERT INTO magic_8ball(phrase, refusal)
        VALUES (?, ?)
    }, undef, ($phrase, $refusal)) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, adding " . $refusal ? 'outcome' : 'refusal' .
        " \"$phrase\" to $module_name"
    );
}

sub magic_8ball_del {
    my ($target, $sender, $phrase) = @_;

    $main::dbh->do(q{
        DELETE FROM magic_8ball
        WHERE phrase=?
    }, undef, $phrase) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, removing \"$phrase\" from $module_name"
    );
}

1;
