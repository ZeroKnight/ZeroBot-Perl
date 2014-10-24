#!/usr/bin/env perl

package ZeroBot::Module::BabelBaba;

use v5.14;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(babelbaba_translate);

use POSIX qw(strftime);

my $module_name = 'BabelBaba';

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
    $main::irc->yield(privmsg => $target => $translation);
}
