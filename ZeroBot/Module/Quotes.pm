#!/usr/bin/env perl

package ZeroBot::Module::Quotes;

use v5.14;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(quote_recite);

my $module_name = 'Quotes';

# TODO: Implement inclusive filtering by phrase, author, submitter, etc
sub quote_recite {
    my ($target, $sender, $phrase, $author, $submitter) = @_;

    my ($authorprefix, $quote);
    $phrase = '.' unless defined $phrase;
    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM quotes
        WHERE author REGEXP ? OR phrase REGEXP ?
        ORDER BY RANDOM() LIMIT 1;
    }, undef, ("(?i:$phrase)", "(?i:$phrase)"));
    given ($ary[5]) {
        when (0) {
            $authorprefix = '';
            $quote = $ary[0];
        } when (1) {
            $authorprefix = "<$ary[1]>";
            $quote = join(' ', $authorprefix, $ary[0]);
        } when (2) {
            $authorprefix = "* $ary[1]";
            $quote = join(' ', $authorprefix, $ary[0]);
        } when (3) { # Technically a suffix :)
            $authorprefix = "- $ary[1]";
            $quote = join(' ', '"'.$ary[0].'"', $authorprefix);
        }
    }
    $main::irc->yield(privmsg => $target => $quote);
}

sub quote_add {
    my ($target, $sender, $author, $phrase, $submitter, $authorprefix) = @_;

    my $preview;
    my @ary = $main::dbh->selectrow_array(q{
        INSERT INTO quotes(phrase, author, submitter, authorprefix)
        VALUES (?, ?, ?, ?)
    }, undef, ($phrase, $author, $submitter, $authorprefix))
    or die $main::dbh->errstr;

    given ($authorprefix) {
        when (0) {
            $preview = "$phrase";
        } when (1) {
            $preview = "<$author> $phrase";
        } when (2) {
            $preview = "* $author $phrase";
        } when (3) {
            $preview = "\"$phrase\" - $author";
        }
    }
    $main::irc->yield(privmsg => $target => "$sender: Okay, adding $preview");
}

1;
