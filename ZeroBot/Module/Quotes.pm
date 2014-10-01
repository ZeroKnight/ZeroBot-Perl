#!/usr/bin/env perl

package ZeroBot::Module::Quotes;

use v5.14;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(quote_recite quote_add quote_del);

use POSIX qw(strftime);

my $module_name = 'Quotes';

# TODO: Implement inclusive filtering by pattern, author, submitter, etc
sub quote_recite {
    my ($target, $sender, $pattern, $author, $submitter) = @_;

    my ($style, $quote);
    $pattern = '.' unless defined $pattern;
    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM quotes
        WHERE author REGEXP ? OR phrase REGEXP ?
        ORDER BY RANDOM() LIMIT 1;
    }, undef, ("(?i:$pattern)", "(?i:$pattern)"));
    given ($ary[5]) {
        when (0) {
            $style = '';
            $quote = $ary[0];
        } when (1) {
            $style = "<$ary[1]>";
            $quote = join(' ', $style, $ary[0]);
        } when (2) {
            $style = "* $ary[1]";
            $quote = join(' ', $style, $ary[0]);
        } when (3) {
            $style = "- $ary[1]";
            $quote = join(' ', '"'.$ary[0].'"', $style);
        }
    }
    $main::irc->yield(privmsg => $target => $quote);
}

sub quote_add {
    my ($target, $sender, $author, $phrase, $submitter, $style) = @_;

    my $quote;
    $style = 1 if !defined $style;
    my $rows = $main::dbh->do(q{
        INSERT INTO quotes (phrase, author, submitter, style, date, time)
        VALUES (?, ?, ?, ?, ?, ?)
    }, undef, ($phrase, $author, $submitter, $style, strftime("%F", localtime), strftime("%T", localtime)));

    given ($style) {
        when (0) {
            $quote = "$phrase";
        } when (1) {
            $quote = "<$author> $phrase";
        } when (2) {
            $quote = "* $author $phrase";
        } when (3) {
            $quote = "\"$phrase\" - $author";
        }
    }
    $main::irc->yield(privmsg => $target => "$sender: Okay, adding: $quote");
}

sub quote_del {
    my ($target, $sender, $author, $phrase) = @_;

    my ($style, $quote);
    my @ary = $main::dbh->selectrow_array(q{
        SELECT * FROM quotes
        WHERE author=? AND phrase=?
    }, undef, ($author, $phrase));
    my $rows = $main::dbh->do(q{
        DELETE FROM quotes
        WHERE author=? AND phrase=?
    }, undef, ($author, $phrase));
    given ($ary[5]) {
        when (0) {
            $style = '';
            $quote = $ary[0];
        } when (1) {
            $style = "<$ary[1]>";
            $quote = join(' ', $style, $ary[0]);
        } when (2) {
            $style = "* $ary[1]";
            $quote = join(' ', $style, $ary[0]);
        } when (3) {
            $style = "- $ary[1]";
            $quote = join(' ', '"'.$ary[0].'"', $style);
        }
    }
    $main::irc->yield(privmsg => $target => "Okay, removing: $quote");
}

1;
