package ZeroBot::Command::Parser;

use ZeroBot::Common -types;

use Carp;
use List::Util 'none';
use ZeroBot::Command::Constants;

use Moo;

has cmd => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::Command'],
  required => 1,
);

has spec => (
  is       => 'ro',
  isa      => HashRef,
  required => 1,
);

has pos => (
  is       => 'rwp',
  isa      => Int,
  default  => sub { 0 },
  init_arg => undef,
);

has end => (
  is       => 'ro',
  isa      => Int,
  builder  => sub { length $_[0]->cmd->line },
  init_arg => undef,
);

has parse_opts => (
  is       => 'rwp',
  isa      => Bool,
  default  => sub { 1 },
  init_arg => undef,
);

has failed => (
  is       => 'rwp',
  isa      => Bool,
  default  => sub { 0 },
  init_arg => undef,
);

has _seen_opt_names => (
  is       => 'rw',
  isa      => HashRef,
  default  => sub { {} },
  init_arg => undef,
);

# Fills in the name, args, and opts attributes of the given ZeroBot::Command
# object. opts will be constructed based on the object's spec attribute
sub parse
{
  my $self = shift;

  # First, attempt to extract command name. Complain if the first character is
  # not the command character.
  unless ($self->_current eq ZBCore->cmdchar)
  {
    Log->debug('Input does not seem to be a command: `'.$self->cmd->line.'`');
    $self->_set_failed(1);
    return $self->cmd;
  }
  $self->_next;

  # Don't bother parsing the rest of the command if it's not expected
  my $name = $self->_get_value;
  return $self->cmd if $self->failed;
  if (exists $self->spec->{$name})
  {
    $self->cmd->_set_name($name);
    $self->cmd->_set_expected(1);
  }
  else
  {
    $self->cmd->_set_expected(0);
    return;
  }
  $self->_next;

  # If the option spec for the command is empty, assume anything that looks like
  # an option is an argument.
  $self->_set_parse_opts(0)
    unless scalar keys %{$self->spec->{$self->cmd->name}};

  # Parse the remainder of the command
  while ($self->pos < $self->end)
  {
    my $c = $self->_current;
    if (!defined $c)
    {
      $self->_error('Unexpected end of input');
    }
    elsif ($c eq ' ')
    {
      $self->_next; # Skip extra non-quoted spaces
    }
    elsif ($c eq '-')
    {
      if ($self->parse_opts)
      {
        # Are we a long option?
        if ($self->_peek eq '-')
        {
          # Check for option terminator: a bare '--'
          # undef is checked here in case a command is terminated with a '--';
          # this is redundant, but valid nonetheless.
          my $p = $self->_peek(2);
          if (!defined $p or $p eq ' ')
          {
            $self->_set_parse_opts(0); # Nothing else will be parsed as an option
            $self->_next(3);
          }
          else
          {
            $self->_get_opt_long;
          }
        }
        else
        {
          if ($self->_peek eq ' ')
          {
            $self->_error('Expected character after option specifier');
            return $self->cmd;
          }
          $self->_get_opt;
        }
      }
      else
      {
        # Not parsing options, just push to the argument stack
        $self->_get_arg;
      }
    }
    else
    {
      $self->_get_arg;
    }
    return $self->cmd if $self->failed;
  }
  $self->cmd->_set_valid(1);
  $self->cmd->_set_argc(scalar @{$self->cmd->args});
  return $self->cmd;
}

# TODO: Alias support
# Returns the atom at the current parser position. An atom is either a single
# word or character, or anything inside quotes.
sub _get_value
{
  my ($self, $delim_pattern) = @_;
  $delim_pattern //= ' ';
  my $value;
  my $in_string = 0;
  my $quote_pos = -1;
  my $c = $self->_current;

  return unless defined $c;
  $c = $self->_next while $c eq ' ';
  while (defined $c)
  {
    if ($c eq '"')
    {
      # NOTE: The parser only recognizes double-quoted strings because the
      # apostrophe is used very frequently in normal writing.
      if ($in_string)
      {
        $quote_pos = -1;
        $in_string = 0;
      }
      else
      {
        $quote_pos = $self->pos;
        $in_string = 1;
      }
      $c = $self->_next;
      next;
    }
    elsif ($c =~ /$delim_pattern/ and not $in_string)
    {
      # Unless we're currently in a quoted string, this is the end of the value
      return $value;
    }
    elsif ($c eq '\\' and not $in_string)
    {
      # If the escaped character becomes magic when escaped, handle it. If not,
      # it will be appended verbatim to $arg
      my $escaped = $self->_peek;
      if ($escaped eq '{')
      {
        # brace expn
        # NOTE: need to handle escaped comma for literal commas
      }
      elsif ($escaped eq '!')
      {
        # history expn
      }
      else
      {
        # Nothing special, skip over the '\' and add the next character verbatim
        $c = $self->_next;
      }
    }

    # Append the processed character to the value
    $value .= $c;
    $c = $self->_next;
  }

  if ($in_string)
  {
    $self->_error('Unterminated string starting', $quote_pos);
    return;
  }
  else
  {
    return $value;
  }
}

sub _get_arg
{
  my $self = shift;
  my $arg = $self->_get_value;
  $self->_next;
  push @{$self->cmd->args}, $arg;
  return $arg;
}

sub _get_opt
{
  my $self = shift;
  my $opt = $self->_next;

  # Make sure we're attemping to parse the correct type of option
  if ($opt eq '-')
  {
    $self->_error('_get_opt() called on long option');
    return;
  }

  if ($opt =~ /[[:alnum:]]/)
  {
    unless ($self->_is_valid_opt($opt))
    {
      $self->_error("Invalid option '-$opt'");
      return;
    }

    # Handle option values, if necessary
    my $req = $self->_optval_required($opt);
    if ($req > OPTVAL_NONE)
    {
      my $n = $self->_peek;
      if (defined $n and $n eq ' ')
      {
        my $val;
        $self->_next(2);
        if ($req == OPTVAL_REQUIRED)
        {
          # Options with required values are greedy, the next atom is consumed
          # as the option's value, even if it looks like another option.
          $val = $self->_get_value;
          unless (defined $val)
          {
            $self->_error("Option '-$opt' expects value");
            return;
          }
          $self->_next;
        }
        else
        {
          # For optional values, the next atom is assumed to be the option
          # value UNLESS it starts with a '-'
          $val = $self->_current eq '-' ? undef : $self->_get_value;
          $self->_next if defined $val;
        }
        $self->cmd->opts->{$opt} = $val;
      }
      elsif (defined $n and $n eq '=')
      {
        # Using equals explicitly denotes a value, regardless of whether an
        # option value is optional or required.
        $self->_next(2);
        my $val = $self->_get_value;
        unless (defined $val)
        {
          $self->_error("Option '-$opt' with explicit equals expects value");
          return;
        }
        $self->cmd->opts->{$opt} = $val;
        $self->_next;
      }
      else
      {
        if ($req == OPTVAL_REQUIRED)
        {
          $self->_error("Option '-$opt' expects value", $self->pos - 1);
          return;
        }

        $self->cmd->opts->{$opt} = undef;
        if (defined $n)
        {
          # Grouped options, so no optional value. Parse the next one.
          $self->_get_opt;
        }
        else
        {
          # Option has optional value, but we're at the end of the command
          $self->_next;
        }
      }
    }
    else # OPTVAL_NONE
    {
      $self->cmd->opts->{$opt} = undef;
      my $p = $self->_peek // ' ';
      if ($p eq '-')
      {
        $self->_error("Erroneous '-' in option grouping", $self->pos + 1);
        return;
      }
      elsif ($p eq '=')
      {
        # Ignore explicit option value; discard result of _get_value
        $self->_warn(
          "Equals given for option '-$opt', but it does not expect a value"
        );
        $self->_get_value;
        $self->_next;
      }
      elsif ($p ne ' ')
      {
        # Grouped options, parse the next one
        $self->_get_opt;
      }
      else
      {
        $self->_next(2);
      }
    }
    # Propagate aliases
    $self->_link_aliases($opt);
  }
  else
  {
    $self->_error("Erroneous option character '$opt'; options must be alphanumeric");
    return;
  }
}

sub _get_opt_long
{
  my $self = shift;
  $self->_next(2);
  my $opt = $self->_get_long_name;

  return unless defined $opt;
  if (length $opt < 2)
  {
    $self->_error("Long options must be at least 2 characters");
    return;
  }

  unless ($self->_is_valid_opt($opt))
  {
    $self->_error("Invalid option '--$opt'", $self->pos - 2);
    return;
  }

  # Handle option values, if necessary
  my $req = $self->_optval_required($opt);
  if ($req > OPTVAL_NONE)
  {
    my $val;
    my $c = $self->_current;
    if (defined $c and $c eq '=')
    {
      # Using equals explicitly denotes a value, regardless of whether an option
      # value is optional or required.
      $self->_next;
      $val = $self->_get_value;
      unless (defined $val)
      {
        $self->_error("Option '--$opt' with explicit equals expects value");
        return;
      }
      $self->_next;
    }
    elsif (defined $c)
    {
      $self->_next;
      if ($req == OPTVAL_REQUIRED)
      {
        # Options with required values are greedy, the next atom is consumed
        # as the option's value, even if it looks like another option.
        $val = $self->_get_value;
        unless (defined $val)
        {
          $self->_error("Option '--$opt' expects value");
          return;
        }
        $self->_next;
      }
      else
      {
        # For optional values, the next atom is assumed to be the option value
        # UNLESS it starts with a '-'
        $val = $self->_current eq '-' ? undef : $self->_get_value;
        $self->_next if defined $val;
      }
    }
    elsif ($req == OPTVAL_REQUIRED)
    {
      $self->_error("Option '--$opt' expects value", $self->pos - 1);
      return;
    }
    $self->cmd->opts->{$opt} = $val;
  }
  else # OPTVAL_NONE
  {
    $self->cmd->opts->{$opt} = undef;
    my $c = $self->_current;
    if (defined $c and $c eq '=')
    {
      # Ignore explicit option value; discard result of _get_value
      $self->_warn(
        "Equals given for option '--$opt', but it does not expect a value"
      );
      $self->_next;
      $self->_get_value;
    }
    $self->_next;
  }
  # Propagate aliases
  $self->_link_aliases($opt);
}

sub _get_long_name
{
  my $self = shift;
  my $name;
  my $c = $self->_current;
  my $start = $self->pos;

  return unless defined $c;
  while (defined $c)
  {
    if ($c =~ /[a-zA-Z0-9-]/)
    {
      $name .= $c;
      $c = $self->_next;
    }
    elsif ($c eq ' ' or $c eq '=')
    {
      return $name;
    }
    else
    {
      $self->_set_pos($start);
      my $badname = $self->_get_value;
      $self->_error("Erroneous option name '$badname'", $start);
      return;
    }
  }
  return $name;
}

# Determines if the given option name is in the option spec
sub _is_valid_opt
{
  my ($self, $opt) = @_;
  foreach my $names (keys %{$self->spec->{$self->cmd->name}})
  {
    return 1 if $opt =~ /\b$names\b/;
  }
  return 0;
}

# Returns whether the given option has a required or optional value, or none
# at all.
sub _optval_required
{
  my ($self, $opt) = @_;
  my $cmdname = $self->cmd->name;
  foreach my $names (keys %{$self->spec->{$cmdname}})
  {
    return $self->spec->{$cmdname}->{$names} if $opt =~ /\b$names\b/;
  }
  return 0;
}

# Given an option that was just set, creates key(s) in $self->cmd->opts for each
# (if any) aliases of the given option, whose values are a copy of the original
# option's value.
sub _link_aliases
{
  my ($self, $opt) = @_;
  my $cmdname = $self->cmd->name;
  return if $self->_seen_opt_names->{$opt};
  foreach my $names (keys %{$self->spec->{$cmdname}})
  {
    next if none { $opt eq $_ } split /\|/, $names;
    foreach my $alias (grep { $_ ne $opt } split /\|/, $names)
    {
      $self->_seen_opt_names->{$alias} = 1;
      $self->cmd->opts->{$alias} = $self->cmd->opts->{$opt};
    }
  }
  $self->_seen_opt_names->{$opt} = 1;
}


# Return the character at the current parser iterator position
sub _current
{
  my $self = shift;
  return $self->_valid ? substr($self->cmd->line, $self->pos, 1) : undef;
}

# Move the parser iterator to the nth next character
sub _next
{
  my ($self, $n) = @_;
  $n //= 1;
  foreach (1..$n)
  {
    return unless $self->_valid;
    $self->_set_pos($self->pos + 1);
  }
  return $self->_current;
}

# Look ahead and return the nth next character, but do not advance
sub _peek
{
  my ($self, $n) = @_;
  $n //= 1;
  return $self->_valid($self->pos + $n) ?
    substr($self->cmd->line, $self->pos + $n, 1) : undef;
}

# Returns whether or not the parser iterator has reached the end of the input
# or if the given index is valid
sub _valid
{
  my ($self, $index) = @_;
  confess "_valid() given negative index: $index" if defined $index and $index < 0;
  return (defined $index ? $index : $self->pos) < $self->end;
}

# Prints the command line with a marker for the current parser position
sub _show_pos
{
  my $self = shift;
  my $line = $self->cmd->line;
  my $pointer = '-' x length $line;
  if ($self->pos == $self->end)
  {
    $pointer .= '^';
  }
  else
  {
    substr $pointer, $self->pos, -1, '^';
    chop $pointer;
  }
  say "$line\n$pointer";
}

sub _error
{
  my ($self, $msg, $pos) = @_;
  $pos //= $self->pos;

  $self->_set_failed(1);

  Log->debug('Command error: ' . $self->_diagmsg($msg, $pos));
}

sub _warn
{
  my ($self, $msg, $pos) = @_;
  $pos //= $self->pos;

  Log->debug('Command: ' . $self->_diagmsg($msg, $pos));
}

sub _diagmsg
{
  my ($self, $msg, $pos) = @_;
  $pos //= $self->pos;
  return "$msg at pos $pos in `".$self->cmd->line.'`';
}

1;
