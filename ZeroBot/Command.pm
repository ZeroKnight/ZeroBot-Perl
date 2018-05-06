package ZeroBot::Command;

use ZeroBot::Common -types;

use Carp;
use ZeroBot::Command::Constants;
use ZeroBot::Command::Parser;

use Moo;

# TODO: build in support for help? ie. auto-generate
# TODO: support incremental options like -vvv?

has line => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has name => (
  is       => 'rwp',
  isa      => Str,
  init_arg => undef,
);

has args => (
  is        => 'rwp',
  isa       => ArrayRef[Str],
  default   => sub { [] },
  predicate => 1,
  init_arg  => undef,
);

has opts => (
  is        => 'rwp',
  isa       => HashRef,
  default   => sub { {} },
  predicate => 1,
  init_arg  => undef,
);

# Set by parse(); used for modules to determine if the parsed command matches
# the spec given to parse()
has expected => (
  is       => 'rwp',
  isa      => Int,
  default  => sub { -1 },
  init_arg => undef,
);

# Set by parse(); if the command is fully parsed without error, this will be
# set to true. Modules should check the validity of a command before
# attempting to use it.
has valid => (
  is       => 'rwp',
  isa      => Bool,
  default  => sub { 0 },
  init_arg => undef,
);

sub parse
{
  my $self = shift;
  my $spec;
  if (ref $_[0] eq 'HASH')
  {
    $spec = $_[0];
  }
  else
  {
    $spec = { @_ };
  }
  $self->_check_spec($spec);
  my $p = ZeroBot::Command::Parser->new(cmd => $self, spec => $spec);
  $p->parse();
}

sub argc
{
  my $self = shift;
  return scalar @{$self->args}
}

sub args_str
{
  my ($self, $delim) = @_;
  $delim //= ' ';
  return join $delim, @{$self->args};
}

sub _check_spec
{
  my ($self, $spec) = @_;
  my %seen;
  croak 'spec must contain at least one command'
    unless scalar keys %{$spec};
  foreach my $cmdname (keys %{$spec})
  {
    foreach my $names (keys %{$spec->{$cmdname}})
    {
      my $req = $spec->{$cmdname}->{$names};
      if (!defined $req or $req < OPTVAL_NONE or $req > OPTVAL_REQUIRED)
      {
        croak 'Values in spec must be between '.OPTVAL_NONE.'-'.OPTVAL_REQUIRED;
      }
      foreach my $opt (split /\|/, $names)
      {
        my $k = "$cmdname:$opt";
        croak "Duplicate option '$opt' in spec '$cmdname:$names', first seen in '$seen{$k}'"
          if exists $seen{$k};
        $seen{$k} = $names;
      }
    }
  }
}

1;
