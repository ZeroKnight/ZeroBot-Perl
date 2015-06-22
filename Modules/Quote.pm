package Modules::Quote;

use strict;
use warnings;
use 5.014; # hashref: keys values on scalars

use parent qw(ZeroBot::Module);
use POSIX qw(strftime mktime);
use Time::Duration;
use YAML::XS qw(LoadFile);

our $Name        = 'Quote'; # NOTE: Can we get this from the package name?
our $Author      = 'ZeroKnight';
our $Description = 'Archive inspiring, humorous, or out-of-context nonsense quotes';

my $config = LoadFile('config/Quote.yaml');
my %lastjoinquote;

# NOTE: make use of dbh->last_insert_id?

sub commanded {
    my ($self, $msg, $cmd) = @_;
    my @arg = @{ $cmd->{arg} };

    return unless $cmd->{name} eq 'quote';
    if (exists $cmd->{opt}{add}) {
        $self->Bot->_compress_arg(0, \@arg) if $arg[0] and $arg[0] =~ /^"/; # XXX
        return if @arg < 2; # TODO: badcmd here
        $self->quote_add($msg->{where}, $msg->{nick}, $arg[0], "@arg[1..$#arg]", $cmd->{opt}{style});
    } elsif (exists $cmd->{opt}{del}) {
        $self->Bot->_compress_arg(0, \@arg) if $arg[0] and $arg[0] =~ /^"/; # XXX
        return if @arg < 2; # TODO: badcmd here
        $self->quote_del($msg->{where}, $msg->{nick}, $arg[0], "@arg[1..$#arg]");
    } elsif (exists $cmd->{opt}{stats}) {
        if (exists $cmd->{opt}{owned}) {
            $self->quote_stats($msg->{where}, $msg->{nick}, $arg[0], 'owned');
        } elsif (exists $cmd->{opt}{submitted}) {
            $self->quote_stats($msg->{where}, $msg->{nick}, $arg[0], 'submitted');
        } else {
            $self->quote_stats($msg->{where}, $msg->{nick}, $arg[0]);
        }
    } elsif (exists $cmd->{opt}{recent}) {
        $self->quote_recent($msg->{where}, $msg->{nick}, $arg[0], $cmd->{opt}{n});
    } else {
        $self->quote_recite($msg->{where}, $arg[0], "@arg[1..$#arg]");
    }
}

sub joined {
    my ($self, $who, $channel) = @_;
    my @optout = @{ $config->{settings}{autooptout} };

    return if $who eq $self->Bot->Nick;
    return if grep {$who eq $_} @optout;

    # Limit auto-recite on a per-user basis to once per configurable interval
    if (time > ($lastjoinquote{$who} || 0) + $config->{settings}{autolimit} * 60) {
        $self->quote_recite($channel, $who);
        $lastjoinquote{$who} = time;
    }
}

sub help {
    return (
        '* quote [author] [pattern] —— Recite a quote',
        '* quote <-add [-style=<style>] | -(del|rem)> <author> <body> —— Add or remove a quote',
        '* quote -stats [-owned | -submitted] [user] —— Return various statistical information about the quote database',
        '* quote -recent [-n=<num>] [author] —— Recite the most recently added quotes',
        "When reciting a quote, both arguments are optional perl-regex patterns that each default to matching anything if omitted. For convenience, a lone '*' is shorthand for '.*'.",
        "When adding/removing a quote, <author> may be wrapped in double-quotes (\") if it is more than one word (eg. !quote -add \"foo bar\" baz!), and if there are multiple authors, separate them with a backslash (\\) (eg. !quote -add -style=0 Foo\\Bar <Foo> bar! | <Bar> yes?).",
        "`style` defines how the quote should be displayed, and can be any of the following (1 is implicit default):",
        "    0: No formatting is applied; WYSIWYG. Useful for quotes with multiple authors.",
        "    1: Author wrapped in angle brackets (<>) and prefixed to the quote. Ex: <foo> bar!",
        "    2: Format the quote to be an ACTION (think: /me). Ex: * foo bars",
        "    3: Literary style; the quote is wrapped in double-quotes and the author is appended to the quote following an em-dash. Ex: \"Bar.\" —foo",
    )
}

sub quote_recite {
    my ($self, $where, $author, $pattern) = @_;
    my $dbh = $self->Bot->_dbh;

    # '*' is syntactic sugar for '.*' in quote command (only if alone)
    $author = '.*' if !$author or $author eq '*';
    $pattern = '.*' if !$pattern or $pattern eq '*';

    my @ary = $dbh->selectrow_array(q{
        SELECT phrase, author, style FROM quote
        WHERE author REGEXP ? AND phrase REGEXP ?
        ORDER BY RANDOM() LIMIT 1;
    }, undef, ("(?i:$author)", "(?i:$pattern)"));
    return unless @ary;

    my $quote = format_quote($ary[1] =~ s|\n|\\|r, $ary[0], $ary[2]);
    $self->privmsg($where, $quote);
    # TODO: set lastquote here
}

sub quote_add {
    my ($self, $where, $submitter, $author, $phrase, $style) = @_;
    my $dbh = $self->Bot->_dbh;

    $style = 1 unless defined $style and $style =~ /\d/;
    my $rows = $dbh->do(q{
        INSERT INTO quote (phrase, author, submitter, style, time)
        VALUES (?, ?, ?, ?, ?)
    }, undef, ($phrase, $author =~ s|\\|\n|r, $submitter, $style, strftime('%s', localtime)));

    my $quote = format_quote($author, $phrase, $style);
    $self->privmsg($where, "$submitter: Okay, adding: $quote");
    # TODO: set lastquote here
}

sub quote_del {
    my ($self, $where, $who, $author, $phrase) = @_;
    my $dbh = $self->Bot->_dbh;

    $author =~ s|\\|\n|;
    my @ary = $dbh->selectrow_array(q{
        SELECT phrase, author, style FROM quote
        WHERE author = ? AND phrase = ?
    }, undef, ($author, $phrase));
    unless (@ary) {
        $self->privmsg($where, "$who: Quote not found...");
        return;
    }
    my $rows = $dbh->do(q{
        DELETE FROM quote
        WHERE author=? AND phrase=?
    }, undef, ($author, $phrase));

    my $quote = format_quote($ary[1], $ary[0], $ary[2]);
    $self->privmsg($where, "$who: Okay, removing: $quote");
    # TODO: set lastquote here
}

sub quote_stats {
    my ($self, $where, $who, $query, $querytype) = @_;
    my $dbh = $self->Bot->_dbh;
    my $msg;
    $querytype ||= '';

    my $totalquotes = ($dbh->selectrow_array('SELECT COUNT(*) FROM quote'))[0];
    unless ($totalquotes) { # Know nothing? Do nothing.
        $self->reply($where, $who, "I don't know any quotes!");
        return;
    }

    if ($query) { # Specific user
        my $ary = $dbh->selectall_arrayref(qq{
            SELECT author, submitter, time FROM quote
            WHERE author REGEXP ? OR submitter REGEXP ?
            ORDER BY time DESC
        }, undef, ("\\n?$query\\n?", $query));
        unless (@$ary) {
            $self->reply($where, $who, sprintf(
                "There are no %s by %s",
                $querytype eq 'owned' ? 'quotes' : 'submissions', $query
            ));
            return;
        }

        # Assign our delicious data
        my ($nquotes, $nsub, $nselfsub) = (0, 0, 0);
        my @lastquote = $self->get_last_quote($query);
        my @lastsub = $self->get_last_quote($query, 'submitter');
        foreach my $row (@$ary) {
            # Credit multi-author quotes
            foreach my $name (split /\n/, $row->[0]) {
                $nquotes++ if $query eq $name;
                $nselfsub++ if $query eq $name and $name eq $row->[1];
            }
            $nsub++ if $query eq $row->[1];
        }
        my $qpercent = sprintf("%.2f", $nquotes / $totalquotes * 100);
        my $spercent = sprintf("%.2f", $nsub / $totalquotes * 100);
        my $sspercent = sprintf("%.2f", $nselfsub / $nquotes * 100);

        # Regurgitate it in various ways
        if ($querytype eq 'owned') {
            $msg = "$query owns $nquotes" . plural(' quote ', $nquotes) .
            "out of $totalquotes total ($qpercent%); $nselfsub ($spercent%) " .
            'of which ' . ($nselfsub == 1 ? 'is' : 'are') . ' self-submitted. ' .
            "The last time they were quoted was on " . datetime_diff($lastquote[3]);
        } elsif ($querytype eq 'submitted') {
            $msg = "$query has submitted $nsub" . plural(' quote ', $nsub) .
            "out of $totalquotes total ($qpercent%); $nselfsub ($spercent%) " .
            'of which ' . ($nselfsub == 1 ? 'is' : 'are') . ' self-authored. ' .
            "The last time they submitted a quote was on " . datetime_diff($lastsub[3]);
        } else {
            $msg = "$query owns $nquotes" . plural(' quote ', $nquotes) .
            "out of $totalquotes total ($qpercent%) and has submitted $nsub " .
            "($spercent%) of them with $nselfsub ($sspercent%) being self-authored. " .
            "The last time they were quoted was on " . datetime_diff($lastquote[3]) .
            ", and the last time they submitted a quote was on " . datetime_diff($lastsub[3]);
        }
    } else { # No one specific, just give us an overview
        my $ary = $dbh->selectall_arrayref(q{
            SELECT author, submitter, time FROM quote
            ORDER BY time DESC
        });
        my $authors = {};
        my %submitters;

        # Gather author/submitter statistics
        foreach my $row (@$ary) {
            foreach my $name (split /\n/, $row->[0]) { # Credit each author
                $authors->{$name}{quotes}++;
                $authors->{$name}{selfsub}++ if $name eq $row->[1];
            }
            $submitters{$row->[1]}++;
        }

        # Assign our delicious data
        my $mostquoted = (
            sort { $authors->{$b}->{quotes} <=> $authors->{$a}->{quotes} } keys $authors
        )[0];
        my $mostsubmitted = (
            sort { $submitters{$b} <=> $submitters{$a} } keys %submitters
        )[0];
        my $nquotes = $authors->{$mostquoted}{quotes};
        my $nsub = $submitters{$mostsubmitted};
        my $nselfsub = $authors->{$mostquoted}{selfsub};
        my $qpercent = sprintf("%.2f", $nquotes / $totalquotes * 100);
        my $spercent = sprintf("%.2f", $nsub / $totalquotes * 100);
        my $sspercent = sprintf("%.2f", $nselfsub / $nquotes * 100);

        # Regurgitate it in various ways
        if ($querytype eq 'owned') {
            $msg = "$mostquoted is the most quoted, with $nquotes" .
            plural(' quote ', $nquotes) . "out of $totalquotes total ($qpercent%); " .
            "$nselfsub ($sspercent%) of which " . ($nselfsub == 1 ? 'is' : 'are') .
            " self-submitted. The last time they were quoted was on " .
            datetime_diff(($self->get_last_quote($mostquoted))[3]);
        } elsif ($querytype eq 'submitted') {
            $msg = "$mostsubmitted has submitted the most quotes, with $nsub" .
            plural(' quote ', $nsub) . "out of $totalquotes total ($spercent%); " .
            "$nselfsub ($sspercent%) of which " . ($nselfsub == 1 ? 'is' : 'are') .
            " self-authored. The last time they submitted a quote was on " .
            datetime_diff(($self->get_last_quote($mostsubmitted, 'submitter'))[3]);
        } else {
            my $nauthors = keys $authors;
            my $nsubmitters = keys %submitters;
            $msg = "I know $totalquotes" . plural(' quote ', $totalquotes) .
            "consisting of $nauthors" . plural(' author ', $nauthors) .
            "and $nsubmitters" . plural(' submitter. ', $nsubmitters) .
            "$mostquoted is the most quoted, with $nquotes ($qpercent%)" .
            plural(' quote', $nquotes) . "; $nselfsub ($sspercent%) of which " .
            ($nselfsub == 1 ? 'is' : 'are') . " self-submitted. $mostsubmitted " .
            "has submitted the most quotes, a total of $nsub ($spercent%). " .
            "The most recent quote was submitted by $ary->[0][1] on " .
            datetime_diff($ary->[0][2]);
        }
    }
    $self->reply($where, $who, $msg);
}

sub quote_recent {
    my ($self, $where, $who, $author, $num) = @_;
    my $dbh = $self->Bot->_dbh;

    $author ||= '.*';
    $num ||= 1;
    $num = 1 if $num < 1;
    $num = 5 if $num > 5;
    my $ary = $dbh->selectall_arrayref(q{
        SELECT phrase, author, style FROM quote
        WHERE author REGEXP ?
        ORDER BY time DESC LIMIT ?
    }, undef, ("(?i:$author)", $num));

    unless (@$ary) {
        $self->reply($where, $who, "There are no quotes by $author");
        return;
    }

    if ($num == 1) {
        $self->reply($where, $who,
            'Here is the most recent quote' . ($author ne '.*' ? " by $author" : '') . ':'
        );
    } else {
        $self->reply($where, $who,
            "Here are the $num most recent quotes" . ($author ne '.*' ? " by $author" : '') . ':'
        );
    }
    foreach my $row (@$ary) {
        my $quote = format_quote($row->[1] =~ s|\n|\\|r, $row->[0], $row->[2]);
        $self->privmsg($where, "— $quote");
    }
}

sub get_last_quote {
    my ($self, $query, $column) = @_;
    my $dbh = $self->Bot->_dbh;
    my @ary;

    if ($query) {
        $column ||= 'author';
        @ary = $dbh->selectrow_array(qq{
            SELECT * FROM quote
            WHERE $column REGEXP ?
            ORDER BY time DESC LIMIT 1
        }, undef, $query);
    } else {
        @ary = $dbh->selectrow_array('SELECT * FROM quote ORDER BY time DESC LIMIT 1');
    }
    return @ary;
}

sub format_quote {
    my ($author, $phrase, $style) = @_;
    my $quote; # End result

    foreach ($style) {
        when (0) { # No formatting
            $style = '';
            $quote = $phrase;
        } when (1) { # Default formatting (IRC Style)
            $style = "<$author>";
            $quote = join(' ', $style, $phrase);
        } when (2) { # ACTION formatting
            $style = "* $author";
            $quote = join(' ', $style, $phrase);
        } when (3) { # "Elegant" formatting
            $style = "—$author";
            $quote = join(' ', '"'.$phrase.'"', $style);
        }
    }
    return $quote;
}

sub plural {
    my ($word, $count) = @_;

    return $count == 1 ? $word : $word =~ s/\b(\w+)\b/$1s/r;
}

sub datetime_diff {
    my $ts = shift;

    return strftime('%F @ %T', localtime($ts)) . ' (' . ago(time - $ts, 3) . ')';
}

1;
