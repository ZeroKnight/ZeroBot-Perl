package ZeroBot::Command::Parser;

use strictures 2;

my %constants;
BEGIN { %constants = (
  OPTVAL_NONE     => 1,
  OPTVAL_OPTIONAL => 2,
  OPTVAL_REQUIRED => 3,
)};
use constant \%constants;

use parent 'Exporter::Tiny';
our @EXPORT = (keys %constants);

use Carp;
use ZeroBot::Common {import => [qw(types)]};

use Moo;

has cmd => (
  is       => 'ro',
  isa      => InstanceOf['ZeroBot::Command'],
  required => 1,
);

has pos => (
  is       => 'rwp',
  isa      => Int,
  default  => sub { 0 },
  init_arg => undef,
);

has end => (
  is      => 'ro',
  isa     => Int,
  builder => sub { length $_[0]->cmd->line },
  init_arg => undef,
);

has parse_opts => (
  is       => 'rwp',
  isa      => Bool,
  default  => sub { 1 },
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
  die 'Input does not seem to be a command: `'.$self->cmd->line.'`'
    unless $self->_current eq ZBCORE->cmdchar;
  $self->_next;
  $self->cmd->_set_name($self->_get_value);

  $DB::single = 1;
  # Parse the remainder of the command
  while ($self->pos < $self->end)
  {
    my $c = $self->_current;
    if ($c eq ' ')
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
          $c = $self->_next(2);

          # Check for option terminator: a bare '--'
          # undef is checked here in case a command is terminated with a '--';
          # this is redundant, but valid nonetheless.
          if (!defined $c or $c eq ' ')
          {
            $self->_set_parse_opts(0); # Nothing else will be parsed as an option
          }
          else
          {
            $self->_get_opt_long;
          }
        }
        else
        {
          die $self->_diagmsg('Expected character after option specifier')
            unless $self->_next;
          $self->_get_opt;
        }
      }
      else
      {
        # No longer parsing options, just push to the argument stack
        $self->_get_arg;
      }
    }
    elsif (!defined $c)
    {
      croak $self->_diagmsg('Unexpected end of input') unless $self->_current;
    }
    else
    {
      $self->_get_arg;
    }
  }
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
      $self->_next;
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
  die $self->_diagmsg('Unterminated string starting', $quote_pos)
    if $in_string;
  $self->_next;
  return $value;
}

sub _get_arg
{
  my $self = shift;
  my $arg = $self->_get_value;
  push @{$self->cmd->args}, $arg;
  return $arg;
}

sub _get_opt
{
  my $self = shift;
  my $opt = $self->_current;

  # Make sure we're attemping to parse the correct type of option
  croak $self->_diagmsg('_get_opt() called on long option') if $opt eq '-';

  if ($opt =~ /[[:alnum:]]/)
  {
    die $self->_diagmsg("Invalid option '-$opt'")
      unless $self->_is_valid_opt($opt);

    # Handle option values, if necessary
    my $req = $self->_optval_required($opt);
    if ($req > OPTVAL_NONE)
    {
      my $n = $self->_next;
      if (defined $n and $n eq ' ')
      {
        $self->_next;
        if ($req == OPTVAL_REQUIRED)
        {
          # Options with required values are greedy, the next atom is consumed
          # as the option's value, even if it looks like another option.
          my $val = $self->_get_value;
          die $self->_diagmsg("Option '-$opt' expects value")
            unless defined $val;
          $self->cmd->opts->{$opt} = $val;
        }
        else
        {
          # For optional values, the next atom is assumed to be the option
          # value UNLESS it starts with a '-'
          $self->cmd->opts->{$opt} = $self->_current =~ /^-/ ? undef
            : $self->_get_value;
        }
      }
      elsif (defined $n and $n eq '=')
      {
        # Using equals explicitly denotes a value, regardless of whether an
        # option value is optional or required.
        $self->_next;
        my $val = $self->_get_value;
        die $self->_diagmsg( "Option '-$opt' with explicit equals expects value")
          unless defined $val;
        $self->cmd->opts->{$opt} = $val;
      }
      else
      {
        die $self->_diagmsg("Option '-$opt' expects value", $self->pos - 1)
          if $req == OPTVAL_REQUIRED;

        # Grouped options, so no optional value. Parse the next one.
        $self->cmd->opts->{$opt} = undef;
        $self->_get_opt;
      }
    }
    else # OPTVAL_NONE
    {
      $self->cmd->opts->{$opt} = undef;
      $self->_next;
      {
        my $p = $self->_current;
        last unless defined $p; # Nothing else to parse, break out
        die $self->_diagmsg("Erroneous '-' in option grouping") if $p eq '-';
        if ($p eq '=')
        {
          # Ignore explicit option value
          carp $self->_diagmsg(
            "Equals given for option '-$opt', but it does not expect a value"
          );
          $self->_get_value;
        }
        elsif ($p ne ' ')
        {
          # Grouped options, parse the next one
          $self->_get_opt;
        }
      }
    }
    # Propagate aliases
    $self->_link_aliases($opt);
  }
  else
  {
    die $self->_diagmsg("Erroneous option character '$opt'; options must be alphanumeric");
  }
}

sub _get_opt_long
{
  my $self = shift;
  my $opt = $self->_get_value(' |=');
  die $self->_diagmsg("Invalid option '--$opt'") unless $self->_is_valid_opt($opt);

  # Handle option values, if necessary
  my $req = $self->_optval_required($opt);
  if ($req > OPTVAL_NONE)
  {
    my $n = $self->_current;
    if (defined $n)
    {
      my $val = $self->_get_value;
      if ($req == OPTVAL_REQUIRED)
      {
        # Options with required values are greedy, the next atom is consumed
        # as the option's value, even if it looks like another option.
        die $self->_diagmsg("Option '--$opt' expects value")
          unless defined $val;
        # $self->cmd->opts->{$opt} = $val;
        $self->_set_opt($opt, $val);
      }
      else
      {
        # For optional values, the next atom is assumed to be the option
        # value UNLESS it starts with a '-'
        $self->cmd->opts->{$opt} = $val unless $val =~ /^-/;
      }
    }
    elsif (defined $n and $n eq '=')
    {
      # Using equals explicitly denotes a value, regardless of whether an
      # option value is optional or required.
      $self->_next;
      my $val = $self->_get_value;
      die $self->_diagmsg("Option '--$opt' with explicit equals expects value")
        unless defined $val;
      $self->cmd->opts->{$opt} = $val;
    }
    else
    {
      die $self->_diagmsg("Option '--$opt' expects value", $self->pos - 1)
        if $req == OPTVAL_REQUIRED;
      $self->cmd->opts->{$opt} = undef;
    }
  }
  else # OPTVAL_NONE
  {
    $self->cmd->opts->{$opt} = undef;
    my $p = $self->_peek;
    if (defined $p and $p eq '=')
    {
      # Ignore explicit option value
      carp $self->_diagmsg("Equals given for option '--$opt', but it does not expect a value");
      $self->_next;
      $self->_get_value;
    }
  }
  # Propagate aliases
  $self->_link_aliases($opt);
}

# Sets an option and its value, taking aliases into account
sub _set_opt
{
  my ($self, $opt, $val) = @_;
  if (exists $self->cmd->opts->{$opt} and ref $self->cmd->opts->{$opt})
  {
    ${$self->cmd->opts->{$opt}} = $val;
  }
  else
  {
    $self->cmd->opts->{$opt} = $val;
  }
}

# Determines if the given option name is in the option spec
sub _is_valid_opt
{
  my ($self, $opt) = @_;
  foreach my $names (keys %{$self->cmd->spec->{$self->cmd->name}})
  {
    return 1 if $opt =~ /$names/;
  }
  return 0;
}

# Returns whether the given option has a required or optional value, or none
# at all.
sub _optval_required
{
  my ($self, $opt) = @_;
  my $cmdname = $self->cmd->name;
  foreach my $names (keys %{$self->cmd->spec->{$cmdname}})
  {
    return $self->cmd->spec->{$cmdname}->{$names} if $opt =~ /$names/;
  }
  return 0;
}

# Given an option that was just set, creates key(s) in $self->cmd->opts for each
# (if any) aliases of the given option, whose values are a reference to the
# original option's value.
sub _link_aliases
{
  my ($self, $opt) = @_;
  my $cmdname = $self->cmd->name;
  return if $self->_seen_opt_names->{$opt};
  foreach my $names (keys %{$self->cmd->spec->{$cmdname}})
  {
    next unless $opt =~ /$names/;
    foreach my $alias (grep { $_ ne $opt } split /\|/, $names)
    {
      $self->_seen_opt_names->{$alias} = 1;
      $self->cmd->opts->{$alias} = \$self->cmd->opts->{$opt};
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
    return undef unless $self->_valid;
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
  croak "_valid() given negative index: $index" if defined $index and $index < 0;
  return (defined $index ? $index : $self->pos) < $self->end;
}

sub _diagmsg
{
  my ($self, $msg, $pos) = @_;
  $pos //= $self->pos;
  return "$msg at pos $pos in `".$self->cmd->line.'`';
}

1;
