package ZeroBot::Command;

use strictures 2;

use Carp;
use Import::Into;
use ZeroBot::Common {import => [qw(types)]};
use ZeroBot::Command::Parser;

# XXX: FIXME: Make OPTVAL_* constants available for construction
BEGIN { ZeroBot::Command::Parser->import::into('ZeroBot::IRC'); }

use Moo;

# TODO: build in support for help? ie. auto-generate
# TODO: support incremental options like -vvv?

has line => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

has spec => (
  is      => 'ro',
  isa     => HashRef,
  default => sub { {} },
);

has name => (
  is  => 'rwp',
  isa => Str,
);

has args => (
  is        => 'rwp',
  isa       => ArrayRef[Str],
  default => sub { [] },
  predicate => 1,
);

has opts => (
  is        => 'rwp',
  isa       => HashRef,
  default => sub { {} },
  predicate => 1,
);

sub BUILD
{
  my $self = shift;
  $self->_check_spec;
  my $p = ZeroBot::Command::Parser->new(cmd => $self);
  $p->parse();
}

sub _check_spec
{
  my $self = shift;
  my %seen;
  croak 'spec must contain at least one command'
    unless scalar keys %{$self->spec};
  foreach my $cmdname (keys %{$self->spec})
  {
    foreach my $names (keys %{$self->spec->{$cmdname}})
    {
      my $req = $self->spec->{$cmdname}->{$names};
      if (!defined $req or $req < OPTVAL_NONE or $req > OPTVAL_REQUIRED)
      {
        croak 'Values in spec must be between '.OPTVAL_NONE.'-'.OPTVAL_REQUIRED;
      }
      foreach my $opt (split /\|/, $names)
      {
        croak "Duplicate name '$opt' in option spec '$names', first seen in '$seen{$opt}'"
          if exists $seen{$opt};
        $seen{$opt} = $names;
      }
    }
  }
}

1;
