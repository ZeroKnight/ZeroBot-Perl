package ZeroBot::IRC::Event::Message;

use ZeroBot::Common -types;

use Carp;

use IRC::Utils qw(lc_irc strip_color strip_formatting);

my %constants;
BEGIN { %constants = (
  MSGTYPE_MESSAGE => 1,
  MSGTYPE_NOTICE  => 2,
  MSGTYPE_ACTION  => 3,
  MSGTYPE_MAX     => 3
)};
use constant \%constants;

our @EXPORT = (keys %constants);
our @EXPORT_OK = qw();

use Moose;
use MooseX::AttributeShortcuts;
extends 'Exporter::Tiny';
with 'ZeroBot::IRC::Event';

has type => (
  is      => 'ro',
  isa     => Int,
  default => MSGTYPE_MESSAGE,
);

has private => (
  is       => 'ro',
  isa      => Bool,
  lazy     => 1,
  init_arg => undef,
  default  => sub { $_[0]->_ispriv() },
);

has message => (
  is       => 'ro',
  isa      => Str,
  required => 1,
);

sub directed
{
  my ($self, $nick) = @_;
  $nick //= $self->network->nick;
  return 0 if $self->type == MSGTYPE_ACTION;
  return 1 if $self->message =~ /^\s*@?$nick[:,]?\s+/;

  # Check casemapped variant as a last resort
  $nick = lc_irc($nick);
  return 1 if lc_irc($self->message) =~ /^\s*@?$nick[:,]?\s+/;
  return 0;
}

sub mentioned
{
  my ($self, $nick) = @_;
  $nick //= $self->network->nick;
  return 1 if $self->message =~ /\b$nick\b/;
  return 1 if $self->message =~ /[[:punct:]] $nick [[:punct:]]/x;

  # Check casemapped variant as a last resort
  $nick = lc_irc($nick);
  return 1 if lc_irc($self->message) =~ /\b$nick\b/;
  return 1 if lc_irc($self->message) =~ /[[:punct:]] $nick [[:punct:]]/x;
  return 0;
}

sub normalize
{
  my $self = shift;
  return strip_formatting(strip_color($self->message));
}

around 'reply' => sub
{
  my ($orig, $self, @args) = @_;
  my $sender = $self->src->nick;

  # If the message is private, there's no need to mention the sender,
  # essentially making this a respond().
  unless ($self->_ispriv())
  {
    unshift @args, "$sender: ";
  }
  $orig->($self, @args);
};

1;
