#!/usr/bin/env perl

package ZeroBot::Module::BabelBaba;

use v5.14;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(is_nonsense babelbaba_translate babelbaba_add babelbaba_del);

my $module_name = 'BabelBaba';

use YAML qw(LoadFile);

sub is_nonsense {
    my $what = shift;

    # Load module configuration
    # FIXME: Need to optimize config loading for modules; don't explicitly load
    # every time a function is called, just when it's updated. This goes for
    # everything config related.
    my $config = LoadFile('config/BabelBaba.yaml');

    # Walk the triggers hash
    while (my ($key, $value) = each $config->{triggers}) {
        foreach my $regex (@{$value}) {
            if (ref $regex eq 'HASH') { # 'fuzzy' hash
                foreach my $fuzzy (@{$regex->{fuzzy}}) {
                    $fuzzy =~ s/(.)/$1+/gs;
                    $fuzzy = "(?i)$fuzzy" if $key eq 'case-insensitive';
                    if ($what =~ /\b$fuzzy\b/) {
                        return 1;
                    }
                }
            } else {
                $regex = "(?i)$regex" if $key eq 'case-insensitive';
                if ($what =~ /\b$regex\b/) {
                    return 1;
                }
            }
        }
    }

    # No matches
    return 0;
}

sub babelbaba_translate {
    my ($target, $sender, $is_auto) = @_;

    my $config = LoadFile('config/BabelBaba.yaml');

    # If intended to be an auto-translation, chance it
    if ($is_auto) {
        unless (int(rand($config->{settings}{'auto-chance'})) == 0) {
            return;
        }
    }

    my $translation;

    # Chance of being unable to translate
    if (int(rand($config->{settings}{'fail-chance'})) == 0) {
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
