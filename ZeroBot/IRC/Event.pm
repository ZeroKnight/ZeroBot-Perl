package ZeroBot::IRC::Event;
# Base class for various user-originating IRC events

use ZeroBot::Common -types;
use ZeroBot::Module 'module_send_event';

use Carp;

use Moose::Role;
use MooseX::AttributeShortcuts;

has network => (
  is       => 'ro',
  isa      => 'ZeroBot::IRC::Network',
  required => 1,
);

has src => (
  is       => 'ro',
  isa      => 'ZeroBot::IRC::User',
  required => 1,
);

has dests => (
  is      => 'ro',
  isa     => 'ArrayRef',
  lazy    => 1,
  default => sub { [ $_[0]->dest ] },
);

# Shortcut for first (or only) destination
has dest => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default => sub { $_[0]->dests->[0] },
);

has time => (
  is      => 'ro',
  isa     => 'Int',
  default => sub { time },
);

has recipient => (
  is       => 'rwp',
  isa      => IRC_Nickname | IRC_Channel,
  lazy     => 1,
  init_arg => undef,
  default  => sub {
    my $self = shift;
    return $self->_ispriv() ? $self->src->nick : $self->dest;
  },
);

sub BUILD
{
  my ($self, $args) = @_;
  croak "Must initialize either dests or dest, but not both"
    unless $args->{dests} xor $args->{dest};
}

# Subclasses are expected to modify reply via `before` or `around` to format
# @msg as appropriate.
sub reply
{
  my ($self, @msg) = @_;
  module_send_event(irc_msg_send => $self->network, $self->recipient, @msg);
}

sub respond
{
  my ($self, @msg) = @_;
  module_send_event(irc_msg_send => $self->network, $self->recipient, @msg);
}

sub emote
{
  my ($self, @action) = @_;
  module_send_event(irc_action_send => $self->network, $self->recipient, @action);
}

sub _ispriv
{
  my $self = shift;
  return $self->dest eq $self->network->nick;
}

1;
