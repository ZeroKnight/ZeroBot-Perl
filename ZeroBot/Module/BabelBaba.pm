#!/usr/bin/env perl

package ZeroBot::Module::BabelBaba;

use v5.14;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(is_nonsense babelbaba_translate babelbaba_add babelbaba_del);

my $module_name = 'BabelBaba';

sub is_nonsense {
    my $what = shift;

    # TODO: Add trigger words
    my @triggers = (
        qr/T_T/,
        qr/(?i)(bobb|jimm|dadd)(eh|y|uh)/,
        qr/(?i)a+u+g+h+/,
        qr/(?i)e+c+u+b+e+/,
        qr/(?i)fecal/,
        qr/(?i)insert/,
        qr/(?i)an(al|us)/,
        qr/(?i)banana/,
        qr/(?i)amish/,
        qr/(?i)d+o+g+s+/,
        qr/(?i)c+a+t+s+/,
        qr/(?i)(corn|carrot|onion|potato|turnip|tomato|lettuce|cabbage)/,
        qr/(?i)vi(t|d)+(a+|u+|le)s+/,
        qr/(?i)poo+pdi+(a+)?ck/,
        qr/(?i)stain/,
        qr/(?i)sphincter/,
        qr/(?i)(dr\.|doctor) phil/,
    );

    foreach my $regex (@triggers) {
        if ($what =~ /$regex/) {
            return 1;
        }
    }
    return 0;
}

sub babelbaba_translate {
    my ($target, $sender) = @_;

    my $translation;

    # 1 in 10 chance of being unable to translate
    if (int(rand(10)) == 1) {
        $translation = '?????????';
    } else {
        my @ary = $main::dbh->selectrow_array(q{
            SELECT * FROM babelbaba
            ORDER BY RANDOM() LIMIT 1;
        });
        $translation = $ary[0];
    }
    $main::irc->yield(privmsg => $target => "Translation: $translation");
}

sub babelbaba_add {
    my ($target, $sender, $phrase) = @_;

    my $rows = $main::dbh->do(q{
        INSERT INTO babelbaba (phrase) VALUES (?)
    }, undef, ($phrase));

    $main::irc->yield(privmsg => $target => "$sender: Okay, adding: $phrase");
}

sub babelbaba_del {
    my ($target, $sender, $phrase) = @_;

    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM babelbaba
        WHERE phrase=?
    }, undef, ($phrase));
    my $rows = $main::dbh->do(q{
        DELETE FROM babelbaba
        WHERE phrase=?
    }, undef, ($phrase));

    $main::irc->yield(privmsg => $target => "Okay, removing: $phrase");
}
