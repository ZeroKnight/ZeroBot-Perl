package ZeroBot::Module::Quote;

use Moose;
use ZeroBot::Common -consts_cmd, -string;
use ZeroBot::Module -std;
use ZeroBot::Util 'clamp';

use List::Util 'any';
use POSIX qw(strftime mktime);
use Time::Duration;

our $Name        = 'Quote';
our $Author      = 'ZeroKnight';
our $Description = 'Archive inspiring, humorous, or out-of-context, nonsensical quotes';

my $dbh;
my $cfg;
my $data;

sub Module_register
{
  my $self = shift;

  # TODO: logging

  module_register($self, 'SERVER', qw(
    commanded
    irc_joined
    irc_msg
    irc_action
  ));

  $cfg = Config->modules->{Quote};
  $dbh = ZBCore->db->new_connection($Name);
  $dbh->do(q{
    CREATE TABLE IF NOT EXISTS [quote] (
      [phrase]    TEXT NOT NULL,
      [author]    TEXT NOT NULL DEFAULT ('Unknown'),
      [submitter] TEXT NOT NULL DEFAULT ('Unknown'),
      [time]      TIMESTAMP DEFAULT (strftime('%s', 'now')),
      [format]    INTEGER NOT NULL DEFAULT (1),
      [id]        INTEGER PRIMrow KEY)
  });

  $data  = {};

  return MODULE_EAT_NONE;
}

sub Module_unregister
{
  my $self = shift;
  ZBCore->db->close_connection($dbh);
}

sub Bot_commanded
{
  my ($self, $core) = splice @_, 0, 2;
  my $cmd = ${ $_[0] };
  $cmd->parse(
    quote => {
      'a|add|n|new'     => OPTVAL_NONE,
      'd|delete|remove' => OPTVAL_NONE,
      't|that'          => OPTVAL_OPTIONAL,
      'f|format'        => OPTVAL_REQUIRED,
      'r|recent'        => OPTVAL_OPTIONAL,
      's|stats'         => OPTVAL_NONE,
      'o|owned'         => OPTVAL_NONE,
      'u|submitted'     => OPTVAL_NONE,
    },
    grab => {}, # TODO: Make a proper alias of this
  );
  return MODULE_EAT_NONE unless $cmd->valid and $cmd->expected;

  if (exists $cmd->{opts}{add})
  {
    if ($cmd->argc < 2)
    {
      $cmd->reply('add requires at least two arguments: an author and a quote');
    }
    else
    {
      quote_add($cmd, shift @{$cmd->args}, $cmd->args_str, $cmd->opts->{format} // 1);
    }
  }
  elsif (exists $cmd->{opts}{that} or $cmd->name eq 'grab')
  {
    quote_grab($cmd, $cmd->args->[0] // $cmd->{opts}{that});
  }
  elsif (exists $cmd->{opts}{delete})
  {
    if ($cmd->argc < 2)
    {
      $cmd->reply('delete requires at least two arguments: an author and a quote');
    }
    else
    {
      quote_del($cmd, shift @{$cmd->args}, $cmd->args_str);
    }
  }
  elsif (exists $cmd->{opts}{stats})
  {
    quote_stats($cmd);
  }
  elsif (exists $cmd->{opts}{recent})
  {
    quote_recent($cmd, $cmd->args->[0] // '.*', $cmd->opts->{recent} // 1);
  }
  else
  {
    quote_recite($cmd, shift @{$cmd->args}, $cmd->args_str);
  }
  return MODULE_EAT_ALL;
}

sub Bot_irc_joined
{
  my ($self, $core) = splice @_, 0, 2;
  my $join = ${ $_[0] };
  my $nick = $join->src->nick;

  return MODULE_EAT_NONE if $nick eq $join->network->nick;
  return if any {$nick eq $_} Config->get_as_list($cfg->{QuoteOnJoin}{ignore});

  # Auto-recite has a configurable cooldown (minutes)
  my $join_hist = $data->{$join->network->name}{$join->dest}{join} //= {};

  if (time > ($join_hist->{$nick} || 0) + $cfg->{QuoteOnJoin}{cooldown} * 60)
  {
    my @rows = $dbh->selectall_array('SELECT id FROM quote WHERE author = ?',
      undef, $nick);
    if ($dbh->errstr)
    {
      $join->respond('Database error :( Take a peek at my log');
      return;
    }
    if (@rows > 0)
    {
      quote_recite($join, $nick);
      $join_hist->{$nick} = time;
    }
  }
  return MODULE_EAT_NONE;
}

sub Bot_irc_action { Bot_irc_msg_(@_, 2) }
sub Bot_irc_msg
{
  my ($self, $core) = splice @_, 0, 2;
  my $msg  = ${ $_[0] };
  my $type = ref $_[1] eq 'SCALAR' ? ${ $_[1] } : 1;

  # Keep track of the last thing a user said or did to allow for quick quotes
  my $last = $data->{$msg->network->name}{$msg->dest}{lastmsg} //= {};
  $last->{$msg->src->nick} = [$msg->message, $type];
  $last->{'!__LAST__'} = $msg->src->nick;

  return MODULE_EAT_NONE;
}

sub quote_recite
{
  my ($ev, $author, $pattern) = @_;

  # '*' is syntactic sugar for '.*' in quote command (only if alone)
  $author = '.*' if !$author or $author eq '*';
  $pattern = '.*' if !$pattern or $pattern eq '*';

  my @row = $dbh->selectrow_array(q{
    SELECT author, phrase, format FROM quote
    WHERE author REGEXP ? AND phrase REGEXP ?
    ORDER BY RANDOM() LIMIT 1;
  }, undef, ("(?i:$author)", "(?i:$pattern)"));
  if ($dbh->errstr)
  {
    $ev->reply("Database error :( Take a peek at my log");
    return;
  }
  elsif (!@row)
  {
    $ev->reply("I couldn't find any quotes like that");
    return;
  }

  my $quote = format_quote($row[0] =~ s|\n|\\|r, @row[1..2]);
  $ev->respond($quote);

  # TODO: set lastquote here (need to account for users with quotes <= to the
  # threshold)
}

sub quote_add
{
  my ($ev, $author, $phrase, $format) = @_;

  my $rows = $dbh->do(q{
    INSERT INTO quote (phrase, author, submitter, format, time)
    VALUES (?, ?, ?, ?, ?)
    }, undef, ($phrase, $author =~ s|,|\n|r, $ev->src->nick, $format,
    strftime('%s', localtime))
  );
  if ($dbh->errstr)
  {
    $ev->reply("Database error :( Take a peek at my log");
    return;
  }

  my $quote = format_quote($author, $phrase, $format);
  $ev->reply("Okay, adding: $quote");
  # TODO: set lastquote here
}

sub quote_grab
{
  my $ev = shift;
  my $last = $data->{$ev->network->name}{$ev->dest}{lastmsg};
  my $author = shift // $last->{'!__LAST__'};
  my ($phrase, $format) = @{$last->{$author}};
  quote_add($ev, $author, $phrase, $format);
}

sub quote_del
{
  my ($ev, $author, $phrase) = @_;
  $author =~ s|,|\n|;

  my @row = $dbh->selectrow_array(q{
    SELECT author, phrase, format FROM quote
    WHERE author = ? AND phrase = ?
  }, undef, ($author, $phrase));
  if ($dbh->errstr)
  {
    $ev->reply("Database error :( Take a peek at my log");
    return;
  }
  elsif (!@row)
  {
    $ev->reply('Quote not found...');
    return;
  }

  my $rows = $dbh->do(q{
    DELETE FROM quote
    WHERE author=? AND phrase=?
  }, undef, ($author, $phrase));
  if ($dbh->errstr)
  {
    $ev->reply("Database error :( Take a peek at my log");
    return;
  }

  my $quote = format_quote(@row);
  $ev->reply("Okay, removing: $quote");
  # TODO: set lastquote here
}

sub quote_stats
{
  my $ev = shift;
  my $query = $ev->args->[0];
  my $query_type = '';
  $query_type    = 'owned'     if exists $ev->opts->{owned};
  $query_type    = 'submitted' if exists $ev->opts->{submitted};

  my $msg;
  my $totalquotes = ($dbh->selectrow_array('SELECT COUNT(*) FROM quote'))[0];
  unless ($totalquotes)
  {
    $ev->reply("I don't know any quotes!");
    return;
  }

  # Specific user
  if ($query)
  {
    my @rows = $dbh->selectall_array(qq{
      SELECT author, submitter, time FROM quote
      WHERE author REGEXP ? OR submitter REGEXP ?
      ORDER BY time DESC
    }, undef, ("(?i:\\n?$query\\n?)", "(?i:$query)"));
    if ($dbh->errstr)
    {
      $ev->reply("Database error :( Take a peek at my log");
      return;
    }
    elsif (!@rows)
    {
      $ev->reply(sprintf("There are no %s by %s",
        $query_type eq 'owned' ? 'quotes' : 'submissions', $query));
      return;
    }

    # Assign our delicious data
    my ($nquotes, $nsub, $nselfsub) = (0, 0, 0);
    my @lastquote = get_last_quote($query);
    my @lastsub   = get_last_quote($query, 'submitter');
    foreach my $row (@rows)
    {
      # Credit multi-author quotes
      foreach my $name (split /\n/, $row->[0])
      {
        $nquotes++  if fc($query) eq fc($name);
        $nselfsub++ if fc($query) eq fc($name) and fc($name) eq fc($row->[1]);
      }
      $nsub++ if fc($query) eq fc($row->[1]);
    }
    my $qpercent  = sprintf("%.2f", $nquotes  / $totalquotes * 100);
    my $spercent  = sprintf("%.2f", $nsub     / $totalquotes * 100);
    my $sspercent = sprintf("%.2f", $nselfsub / $nquotes * 100);

    # Regurgitate it in various ways
    if ($query_type eq 'owned')
    {
      $msg = "$query owns $nquotes" . pluralize(' quote(s) ', $nquotes) .
      "out of $totalquotes total ($qpercent%); $nselfsub ($spercent%) " .
      'of which ' . ($nselfsub == 1 ? 'is' : 'are') . ' self-submitted. ' .
      "The last time they were quoted was on " . datetime_diff($lastquote[3]);
    }
    elsif ($query_type eq 'submitted')
    {
      $msg = "$query has submitted $nsub" . pluralize(' quote(s) ', $nsub) .
      "out of $totalquotes total ($qpercent%); $nselfsub ($spercent%) " .
      'of which ' . ($nselfsub == 1 ? 'is' : 'are') . ' self-authored. ' .
      "The last time they submitted a quote was on " . datetime_diff($lastsub[3]);
    }
    else
    {
      $msg = "$query owns $nquotes" . pluralize(' quote(s) ', $nquotes) .
      "out of $totalquotes total ($qpercent%) and has submitted $nsub " .
      "($spercent%) of them with $nselfsub ($sspercent%) being self-authored. " .
      "The last time they were quoted was on " . datetime_diff($lastquote[3]) .
      ", and the last time they submitted a quote was on " . datetime_diff($lastsub[3]);
    }
  }
  else
  {
    # No one specific, just give us an overview
    my $row = $dbh->selectall_arrayref(q{
      SELECT author, submitter, time FROM quote
        ORDER BY time DESC
    });
    my $authors = {};
    my %submitters;

    # Gather author/submitter statistics
    foreach my $row (@$row)
    {
      foreach my $name (split /\n/, $row->[0])
      {
        # Credit each author
        $authors->{$name}{quotes}++;
        $authors->{$name}{selfsub}++ if $name eq $row->[1];
      }
      $submitters{$row->[1]}++;
    }

    # Assign our delicious data
    my $mostquoted = (
        sort { $authors->{$b}->{quotes} <=> $authors->{$a}->{quotes} } keys %$authors
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
    if ($query_type eq 'owned')
    {
      $msg = "$mostquoted is the most quoted, with $nquotes" .
      pluralize(' quote(s) ', $nquotes) . "out of $totalquotes total ($qpercent%); " .
      "$nselfsub ($sspercent%) of which " . ($nselfsub == 1 ? 'is' : 'are') .
      " self-submitted. The last time they were quoted was on " .
      datetime_diff((get_last_quote($mostquoted))[3]);
    }
    elsif ($query_type eq 'submitted')
    {
      $msg = "$mostsubmitted has submitted the most quotes, with $nsub" .
      pluralize(' quote(s) ', $nsub) . "out of $totalquotes total ($spercent%); " .
      "$nselfsub ($sspercent%) of which " . ($nselfsub == 1 ? 'is' : 'are') .
      " self-authored. The last time they submitted a quote was on " .
      datetime_diff((get_last_quote($mostsubmitted, 'submitter'))[3]);
    }
    else
    {
      my $nauthors = keys %$authors;
      my $nsubmitters = keys %submitters;
      $msg = "I know $totalquotes" . pluralize(' quote(s) ', $totalquotes) .
      "consisting of $nauthors" . pluralize(' author(s) ', $nauthors) .
      "and $nsubmitters" . pluralize(' submitter(s). ', $nsubmitters) .
      "$mostquoted is the most quoted, with $nquotes ($qpercent%)" .
      pluralize(' quote(s)', $nquotes) . "; $nselfsub ($sspercent%) of which " .
      ($nselfsub == 1 ? 'is' : 'are') . " self-submitted. $mostsubmitted " .
      "has submitted the most quotes, a total of $nsub ($spercent%). " .
      "The most recent quote was submitted by $row->[0][1] on " .
      datetime_diff($row->[0][2]);
    }
  }
  $ev->reply($msg);
}

sub quote_recent
{
  my ($ev, $author, $num) = @_;
  if ($num =~ /^\d+$/)
  {
    $num = clamp($num, 1, 5);
  }
  else
  {
    # Assume that the user probably meant "most recent by this author"
    # !quote -r foo
    $author = $num;
    $num = 1;
  }

  my @row = $dbh->selectall_array(q{
    SELECT author, phrase, format FROM quote
    WHERE author REGEXP ?
    ORDER BY time DESC LIMIT ?
  }, undef, ("(?i:$author)", $num));
  if ($dbh->errstr)
  {
    $ev->reply("Database error :( Take a peek at my log");
    return;
  }
  elsif (!@row)
  {
    $ev->reply("I couldn't find any quotes like that");
    return;
  }

  $ev->reply(pluralize('Here (is|are) the (%d )most recent quote(s)', $num),
    ($author eq '.*' ? '' : " by $author"), ': ');

  foreach my $row (@row)
  {
    my $quote = format_quote($row->[0] =~ s|\n|\\|r, @$row[1..2]);
    $ev->respond( "— $quote");
  }
}

sub get_last_quote
{
  my ($query, $column) = @_;
  my @row;
  if ($query) {
    $column ||= 'author';
    @row = $dbh->selectrow_array(qq{
      SELECT * FROM quote
      WHERE $column REGEXP ?
      ORDER BY time DESC LIMIT 1
    }, undef, "(?i:$query)");
  }
  else
  {
    @row = $dbh->selectrow_array('SELECT * FROM quote ORDER BY time DESC LIMIT 1');
  }
  return @row;
}

sub format_quote
{
  my ($author, $phrase, $format) = @_;
  my $quote; # End result

  no warnings 'experimental::smartmatch';
  foreach ($format) {
    when (0) # No formatting
    {
      $format = '';
      $quote = $phrase;
    }
    when (1) # Default formatting (IRC format)
    {
      $format = "<$author>";
      $quote = join(' ', $format, $phrase);
    }
    when (2) # ACTION formatting
    {
      $format = "* $author";
      $quote = join(' ', $format, $phrase);
    }
    when (3) # "Elegant" formatting
    {
      $format = "—$author";
      $quote = join(' ', '"'.$phrase.'"', $format);
    }
  }
  return $quote;
}

sub datetime_diff
{
  my $ts = shift;
  return strftime('%F @ %T', localtime($ts)) . ' (' . ago(time - $ts, 3) . ')';
}

1;
