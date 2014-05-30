#!/usr/bin/env perl

package ZeroBot::Module::Question;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(is_question answer_question question_add question_del);

my $module_name = 'Question';

sub is_question {
    my $what = shift;

    my $me = $main::irc->nick_name;

    # TODO: add variety/variances
    my @patterns = (
        qr/right,? $me\s?\??/i,
        qr/$me[:,]? .*(right)?\?/,
        qr/,? $me\?/,
        qr/(dis)?agree(s|d|ment)?,? .*$me\s?\??/,
    );

    foreach my $regex (@patterns) {
        if ($what =~ /$regex/) {
            return 1;
        }
    }
    return 0;
}

sub answer_question {
    my ($target, $sender) = @_;

    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM question
        WHERE agree=?
        ORDER BY RANDOM() LIMIT 1;
    }, undef, int(rand(3))) or die $main::dbh->errstr;
    if ($ary[1]) {
        $main::irc->yield(ctcp => $target => "ACTION $ary[0]");
    } else {
        $main::irc->yield(privmsg => $target => $ary[0]);
    }
}

sub question_add {
    my ($target, $sender, $phrase, $action) = @_;

    $main::dbh->do(q{
        INSERT INTO question(phrase, action)
        VALUES (?, ?)
    }, undef, ($phrase, int($action))) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, adding " . $action ? 'action' : 'phrase' .
        " \"$phrase\" to $module_name"
    );
}

sub question_del {
    my ($target, $sender, $phrase) = @_;

    $main::dbh->do(q{
        DELETE FROM question
        WHERE phrase=?
    }, undef, $phrase) or die $main::dbh->errstr;
    $main::irc->yield(privmsg => $target =>
        "$sender: Okay, removing \"$phrase\" from $module_name"
    );
}

1;
