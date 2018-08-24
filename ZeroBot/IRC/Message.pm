package ZeroBot::IRC::Message;

use ZeroBot::Common -types;

my %constants;
BEGIN { %constants = (
  MSGTYPE_MESSAGE => 1,
  MSGTYPE_NOTICE  => 2,
  MSGTYPE_ACTION  => 3,
  MSGTYPE_MAX     => 3
)};
use constant \%constants;

use parent 'Exporter::Tiny';
our @EXPORT = (qw(), keys %constants);
our @EXPORT_OK = qw();

use Carp;

use IRC::Utils qw(lc_irc strip_color strip_formatting);

use Moo;
with map("ZeroBot::IRC::$_", qw/Event Answerable/);

has '+src' => (isa => InstanceOf['ZeroBot::IRC::User']);

has type => (
  is      => 'ro',
  isa     => Int,
  default => MSGTYPE_MESSAGE,
);

has private => (
  is      => 'ro',
  isa     => Bool,
  default => 0,
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

1;
