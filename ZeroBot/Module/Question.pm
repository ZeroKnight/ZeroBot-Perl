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
# $bias is the answer type to be biased toward. Values are identical to their
# mapped value in the DB. 0 = Negative, 1 = Positive, 2 = Indifferent
# If $bias is undef, normal behavior occurs
    my ($target, $sender, $bias) = @_;
    my $atype = int(rand(3));

    if (defined $bias) {
        # 3:1 chance of using being biased
        $atype = $bias unless int(rand(3)) == 0;
    }

    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM question
        WHERE agree=?
        ORDER BY RANDOM() LIMIT 1;
    }, undef, $atype) or die $main::dbh->errstr;
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
